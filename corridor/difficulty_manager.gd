extends Node

enum Difficulty { EASY, MEDIUM, HARD }
var current_difficulty: Difficulty = Difficulty.MEDIUM

# Maze
var maze_cols := 15
var maze_rows := 15
var change_interval := 30.0
var trap_density := 0.25

# Monster
var has_monster := true
var monster_speed_mult := 1.0
var monster_damage_mult := 1.0
var monster_vision_mult := 1.0

# Player
var player_max_health := 75.0
var player_speed_mult := 1.0

func apply_difficulty(diff: Difficulty):
	current_difficulty = diff
	match diff:
		Difficulty.EASY:
			maze_cols = 11
			maze_rows = 11
			change_interval = 45.0
			trap_density = 0.1
			has_monster = false
			player_speed_mult = 1.3
			player_max_health = 100.0
		Difficulty.MEDIUM:
			maze_cols = 15
			maze_rows = 15
			change_interval = 30.0
			trap_density = 0.25
			has_monster = true
			monster_speed_mult = 1.0
			monster_damage_mult = 1.0
			monster_vision_mult = 1.0
			player_speed_mult = 1.0
			player_max_health = 75.0
		Difficulty.HARD:
			maze_cols = 19
			maze_rows = 19
			change_interval = 20.0
			trap_density = 0.35
			has_monster = true
			monster_speed_mult = 1.3
			monster_damage_mult = 1.5
			monster_vision_mult = 1.3
			player_speed_mult = 0.8
			player_max_health = 50.0
