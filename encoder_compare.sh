#!/bin/env sh

set -e

# input file
REFERENCE=testvideo-fhd-yuv422p-ffv1.mkv

# h264_nvenc, hevc_nvenc, libx264, libx265, libsvtav1
ENCODER=h264_nvenc

# hevc_nvenc / h264_nvenc : p1-p7, higher=higher quality / slower encoding - has practically absolutely no meaning for my hw
# libsvtav1               : -0-13, default -1 ("auto" - same as 10), lower=higher quality / slower encoding
# libx264                 : ultrafast superfast veryfast faster fast medium slow slower veryslow
# libx265                 : ultrafast superfast veryfast faster fast medium slow slower veryslow
PRESETS="p4 p7"

# hevc_nvenc / h264_nvenc  cq: 0-51, default: 0 (automatic), lower values correspond to higher quality and greater file size.
# libsvtav1               CRF: 0-63, default 50. lower values correspond to higher quality and greater file size.
# libx264                 CRF: 0-51, 0=lossless
# libx265                 CRF: -1 - FLT_MAX, default -1, ??? 
#QUALITIES="30 35 40"
QUALITIES=$(seq 16 2 50) # for 16 - 50 step 2

# VMAF model:
#  FHD: 1920x1080
#  4K:  3840x2160
VMAFMODEL=FHD

FFMPEG="ffmpeg"

# summary csv file
SUMMARY=measurement-summary.csv

####################


echo "testing qualities ($(echo $QUALITIES | xargs echo)) for presets ($(echo $PRESETS | xargs echo))"

do_encode() {
  echo "encode: $ENCODER preset:$PRESET, quality:$QUALITY -> $FFMPEGOUT"
  GLOBAL_OPTIONS="-y -hide_banner -benchmark"
  export FFREPORT=level=32:file=$FFMPEGOUT
  case "$ENCODER" in
    hevc_nvenc) 
      $FFMPEG $GLOBAL_OPTIONS -i "$REFERENCE" -c:v $ENCODER -tune:v hq -rc:v vbr -cq:v $QUALITY -preset:v $PRESET -b_ref_mode 0 "$DISTORTED"
      ;;
    h264_nvenc) 
      $FFMPEG $GLOBAL_OPTIONS -i "$REFERENCE" -c:v $ENCODER -tune:v hq -rc:v vbr -cq:v $QUALITY -preset:v $PRESET -coder:v cabac "$DISTORTED"
      ;;
    libx264) 
      $FFMPEG $GLOBAL_OPTIONS -i "$REFERENCE" -c:v $ENCODER -crf $QUALITY -preset:v $PRESET -coder:v cabac "$DISTORTED"
      ;;
    libx265) 
      $FFMPEG $GLOBAL_OPTIONS -i "$REFERENCE" -c:v $ENCODER -crf $QUALITY -preset:v $PRESET "$DISTORTED"
      ;;
    libsvtav1) 
      $FFMPEG $GLOBAL_OPTIONS -i "$REFERENCE" -c:v $ENCODER -crf $QUALITY -preset:v $PRESET -g 150 "$DISTORTED"
      ;;
    *) exit 1 ;;
  esac
}

measure_quality() {
  unset FFREPORT
  $FFMPEG -hide_banner -i $DISTORTED -i $REFERENCE \
    -filter_complex  "\
    [0:v]setpts=PTS-STARTPTS[distorted]; \
    [1:v]setpts=PTS-STARTPTS[reference]; \
    [distorted][reference]libvmaf=feature='name=psnr|name=float_ssim':model='version=$VMAFMODEL_FILE':n_threads=4:log_fmt=json:log_path=./$VMAFLOG" \
     -f null -
}

export LC_ALL=C 
ROUND2="xargs printf %.*f 2"

add_stats() {
if [ ! -f "$SUMMARY" ]; then
    echo "encoder;quality parameter;preset;file size;utime;rtime;stime;vmaf mean;ssim mean;psnr y mean;psnr cb mean;psnr cr mean;vmaf min;vmaf max;ssim min;ssim max;maxrss" > "$SUMMARY"
  fi
  echo "$ENCODER;$QUALITY;$PRESET;\
$(ls -s --block-size=M $DISTORTED | cut -d ' ' -f1);\
$(cat $FFMPEGOUT | grep bench | sed -r -n 's/.*utime=([0-9\.]+)s\s*stime=([0-9\.]+)s\s*rtime=([0-9\.]+)s/\1;\2;\3/p');\
$(jq .pooled_metrics.vmaf.mean $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.float_ssim.mean $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.psnr_y.mean $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.psnr_cb.mean $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.psnr_cr.mean $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.vmaf.min $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.vmaf.max $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.float_ssim.max $VMAFLOG | $ROUND2);\
$(jq .pooled_metrics.float_ssim.min $VMAFLOG | $ROUND2);\
$(cat $FFMPEGOUT | grep bench | sed -r -n 's/.*maxrss=(.*)$/\1/p')" >> "$SUMMARY"

}

case "$VMAFMODEL" in
  FHD)
    VMAFMODEL_FILE="vmaf_v0.6.1"
    ;;
  4K)
    VMAFMODEL_FILE="vmaf_4k_v0.6.1"
    ;;
  *) exit 1 ;;
esac


for PRESET in $PRESETS
do
  for QUALITY in $QUALITIES
  do
    DISTORTED=encode-$ENCODER-q$QUALITY-p$PRESET.mkv
    VMAFLOG=vmaf-log-$ENCODER-q$QUALITY-p$PRESET.json
    FFMPEGOUT=ffmpeg-out-$ENCODER-q$QUALITY-p$PRESET.log

    if [ -f "$SUMMARY" ] && [ ! -z $(grep "$ENCODER;$QUALITY;$PRESET" "$SUMMARY") ]; then
        echo "skipping $DISTORTED"
        continue
    fi

    do_encode
    measure_quality
    add_stats

    done
done

