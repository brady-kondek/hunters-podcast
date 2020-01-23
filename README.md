# Standardformate:

mp3: 128kBit
opus: 128kBit


# Umwandlung von mp3 in opus:

avconv -i episodexx.mp3 -f wav - | opusenc --bitrate 128 - episodexx.opus
