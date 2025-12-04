# Project description

* Continously record 10 second video clips from the camera
* Monitor camera events coming to MQTT
* Check when the previous event was handled. If events appear too often, skip part of them by using exponential backoff
* Capture a picture from the video stream and send it to Telegram
* Copy the two latest video clips to S3
* Send private links of the S3 videos to Telegram

# Technical decisions

* Each camera stream is monitored by a separate environment
* Each environment is monitoring one MQTT queue
