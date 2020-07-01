import time
import json

import io

import subprocess
import RPi.GPIO as GPIO
from time import sleep

import pyaudio
import wave

#GOOGLE_APPLICATION_CREDENTIALS = "/home/pi/Desktop/hub_demo/test/SpeechtoText-b3041d4cfba4.json"

BUTTON_PIN = 5
LED_PIN = 3
Led_status = 1

BUTTON_STATUS = False

CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000
RS_ID = 0
WAVE_OUTPUT_FILENAME = "/home/pi/Desktop/hub_demo/resource_chatbot/output.wav"
WAVE_OUTPUT_FROM_CLOUD_FILENAME = "/home/pi/Desktop/hub_demo/resource_chatbot/output_fromtext.wav"
TEXT_OUTPUT_FROM_CLOUD_FILENAME = "/home/pi/Desktop/hub_demo/resource_chatbot/output_fromaudio.txt"

# This Chochae URL use for local host in Atapy LAN
Chochae_url = "http://192.168.0.174:8084/response?text="

text_ = " "

def button_callback(channel):
        global BUTTON_STATUS
        BUTTON_STATUS = not BUTTON_STATUS

def sample_recognize(local_file_path):
        '''
        Transcribe a long audio file using asynchronous speech recognition

        Args:
          local_file_path Path to local audio file, e.g. /path/audio.wav
        '''
        from google.cloud import speech_v1p1beta1
        from google.cloud.speech_v1p1beta1 import enums

        global text_
        text_ = " "

        client = speech_v1p1beta1.SpeechClient()

        enable_automatic_punctuation = True

        # The language of the supplied audio
        language_code = "th-TH"

        # Encoding of audio data sent. This sample sets this sample sets this explicitly.
        # This field is optional for FLAC and WAV audio formats.
        encoding = enums.RecognitionConfig.AudioEncoding.LINEAR16
        config = {
                "enable_automatic_punctuation": enable_automatic_punctuation,
                "encoding": encoding,
                "language_code": language_code,
        }
        with io.open(local_file_path, "rb") as f:
                content = f.read()
        audio = {"content": content}

        print(u"Waiting for operation to complete...")
        response = client.recognize(config, audio)

        for result in response.results:
                # First alternative is the most probable result
                alternative = result.alternatives[0]
                text_ = alternative.transcript

def text_to_speech(text):
        from google.cloud import texttospeech

        client = texttospeech.TextToSpeechClient()

        synthesis_input = texttospeech.SynthesisInput(text=text)

        voice = texttospeech.VoiceSelectionParams(
                language_code="th-TH", ssml_gender=texttospeech.SsmlVoiceGender.NEUTRAL
        )

        audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.LINEAR16
        )

        response = client.synthesize_speech(
                input=synthesis_input, voice=voice, audio_config=audio_config
        )

        with open(WAVE_OUTPUT_FROM_CLOUD_FILENAME, "wb") as out:
                out.write(response.audio_content)
                print('Audio content written to file "output_fromtext.wav"')

def request_for_chatbot(text):
        import requests
        global request_text

        url = Chochae_url + text
        response = requests.get(url=url)
        request_text = response.text.split("\"")

def main():
        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BOARD)
        GPIO.setup(LED_PIN, GPIO.OUT, initial=GPIO.LOW)
        GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        GPIO.add_event_detect(BUTTON_PIN, GPIO.FALLING, callback=button_callback, bouncetime=100)

        while True:
                try:
                        if BUTTON_STATUS:
                                p = pyaudio.PyAudio()

                                stream = p.open(rate=RATE,
                                                format=FORMAT,
                                                channels=CHANNELS,
                                                input=True,
                                                input_device_index=RS_ID,)

                                print("* recording")

                                frames = []

                                while(BUTTON_STATUS):
                                        GPIO.output(LED_PIN, GPIO.HIGH)
                                        data = stream.read(CHUNK)
                                        frames.append(data)
                                        GPIO.output(LED_PIN, GPIO.LOW)

                                print("* done recording")

                                stream.stop_stream()
                                stream.close()
                                p.terminate()

                                wf = wave.open(WAVE_OUTPUT_FILENAME, 'wb')
                                wf.setnchannels(CHANNELS)
                                wf.setsampwidth(p.get_sample_size(FORMAT))
                                wf.setframerate(RATE)
                                wf.writeframes(b''.join(frames))
                                wf.close()

                                import argparse

                                parser = argparse.ArgumentParser()

                                parser.add_argument(
                                        "--local_file_path", type=str, default=WAVE_OUTPUT_FILENAME
                                )
                                args = parser.parse_args()

                                sample_recognize(args.local_file_path)
                                request_for_chatbot(text_)
                                text_to_speech(request_text[3])
                                subprocess.run(["aplay", "-f", "cd", WAVE_OUTPUT_FROM_CLOUD_FILENAME])

                except IOError as e:
                        print(e)
                        continue

if __name__ == "__main__":
        main()