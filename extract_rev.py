import wave, os

# Paths
base_path = r"C:/Users/samue/Desktop/CustomVeloz/Sonidos_Carros/CarroRally_Personaje"
src_file = os.path.join(base_path, "motor_loop.wav")
out_file = os.path.join(base_path, "motor_rev.wav")

# Offset in seconds (adjusted after testing)
OFFSET_SEC = 2.5

with wave.open(src_file, 'rb') as src:
    params = src.getparams()
    framerate = src.getframerate()
    n_channels = src.getnchannels()
    sampwidth = src.getsampwidth()
    start_frame = int(OFFSET_SEC * framerate)
    src.setpos(start_frame)
    frames = src.readframes(src.getnframes() - start_frame)

with wave.open(out_file, 'wb') as out:
    out.setnchannels(n_channels)
    out.setsampwidth(sampwidth)
    out.setframerate(framerate)
    out.writeframes(frames)

print('Extracted rev segment to', out_file)
