extends Node

signal current_score_updated(score)
signal current_combo_updated(combo)

signal song_begin
signal song_end

# Emitted when a song is selected in the menu (carries the map loader instance)
signal song_selected(map)

# Playlist signals
signal playlist_song_started(song_index: int, total_songs: int)
signal playlist_completed
