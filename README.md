# Comparing impact of encoder flags on output quality, file size and encoding time

- Runs ffmpeg encoding series with varying encoder preset and VBR parameter
- Measures encoding time, file size and output quality with several models
- Adds statistics to CSV file

## Requirements

- ffmpeg built with support for libvmaf and the encoder to test
- a unix shell, like bash
- sed, jq to process output
- proper video footage

## How to find best fitting encoder parameters?

1. Prepare test footage.
   * To speed up the process it's a good idea to select a sub scene instead of the whole footage. (The scene matters to quality and size outputs. One could also select several sub cenes and put it together.)
   * Also, if the final output should be filtered, scaled or have converted pixel format, it's best to apply this to the test footage once instead to apply it in each test step. 
   * Encode with lossless codec so so the measurement gets clean input as in the final encoding step.
   * For VMAF measurement it's best to have either full-HD (1920x1080) or 4k (3840x2160) content.
   * An example to prepare test footage with ffmpeg would be:
    ```bash
    ffmpeg \
        -ss 20:00 -t 00:30 `# select 30sec at minute 20` \
        -i input.mp4 \
        -map 0:v  `# only use video` \
        -vf scale=-1:1080:flags=bicubic `# assuming 16:9, scale to 1920x1080` \
        -pix_fmt yuv420p `# convert to yuv420p` \
        -c:v ffv1 `# encode with lossless ffv1 codec` \
        testvideo-fhd-yuv422p-ffv1.mkv
    ```
2. Edit settings in the script, start with rather huge steps between preset / quality parameters for a first glance. Execute the script.
3. Inspect the measurements in CSV output. Choose which values fit the needs most, refine parameters, restart at step 3 until best outcome is clear.
4. Final encoding. Use parameters on original footage.


## Lessons learned
* A mean vmaf score of 90 and up is supposed very good quality, 80 and up quite good
* Mean psnr around 40 is very good
* for hevc_nvenc / h264_nvenc, changing the preset has practically no influence on quality / output size, at least for my GTX 1060
* h264_nvenc cq below 24 (4k) / 22 (fhd) don't give any change in quality and output size
* hevc_nvenc cq below 30 (4k) / 26 (fhd) don't give any change in quality and output size

