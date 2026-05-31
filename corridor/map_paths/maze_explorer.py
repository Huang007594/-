#!/usr/bin/env python3
"""
第一人称走蓝迷宫 —— 终端3D探索
在蓝色水域中移动，用WASD控制视角，Q退出。
"""
import os
import sys
import random
import math
from collections import deque

# ==================== 迷宫生成（元胞自动机） ====================
def generate_maze(w=60, h=60, wall_chance=0.45, steps=5, threshold=4):
    grid = [[1] * w for _ in range(h)]
    for y in range(1, h-1):
        for x in range(1, w-1):
            grid[y][x] = 1 if random.random() < wall_chance else 0
    for _ in range(steps):
        new = [row[:] for row in grid]
        for y in range(1, h-1):
            for x in range(1, w-1):
                cnt = 0
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        if dx==0 and dy==0: continue
                        nx, ny = x+dx, y+dy
                        cnt += grid[ny][nx] if 0<=nx<w and 0<=ny<h else 1
                new[y][x] = 1 if cnt >= threshold else 0
        grid = new
    # 保留最大水域连通区
    visited = [[False]*w for _ in range(h)]
    best = set()
    for y in range(h):
        for x in range(w):
            if grid[y][x] == 0 and not visited[y][x]:
                region = set()
                q = deque([(x,y)])
                visited[y][x] = True
                while q:
                    cx, cy = q.popleft()
                    region.add((cx,cy))
                    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                        nx, ny = cx+dx, cy+dy
                        if 0<=nx<w and 0<=ny<h and grid[ny][nx]==0 and not visited[ny][nx]:
                            visited[ny][nx] = True
                            q.append((nx,ny))
                if len(region) > len(best):
                    best = region
    for y in range(h):
        for x in range(w):
            if grid[y][x] == 0 and (x,y) not in best:
                grid[y][x] = 1
    # 随机起点（水域中）
    water = [(x,y) for y in range(h) for x in range(w) if grid[y][x]==0]
    start = random.choice(water)
    return grid, w, h, start

# ==================== 射线投射引擎 ====================
FOV = math.pi / 3.0       # 视野角度60°
SCREEN_WIDTH = 120        # 终端列数（可调）
MAX_DEPTH = 30.0
WALL_HEIGHT_FACTOR = 12   # 墙高度系数

# ANSI 颜色
RESET = "\033[0m"
BLUE_BG = "\033[48;2;30;130;230m"   # 水面蓝背景
GRAY_BG = "\033[48;2;80;80;80m"     # 岩壁灰背景
DARK_BG = "\033[48;2;30;30;30m"     # 远处暗色
BLACK_BG = "\033[40m"
CLEAR = "\033[2J\033[H"

def cast_rays(grid, w, h, px, py, angle):
    """返回一个长度为SCREEN_WIDTH的列表，每个元素为 (距离, 是否墙)"""
    result = []
    for i in range(SCREEN_WIDTH):
        ray_angle = angle - FOV/2 + (i / SCREEN_WIDTH) * FOV
        sin_a = math.sin(ray_angle)
        cos_a = math.cos(ray_angle)
        # DDA射线步进
        dist = 0.0
        x, y = px, py
        step_size = 0.05
        hit_wall = False
        while dist < MAX_DEPTH:
            dist += step_size
            x = px + cos_a * dist
            y = py + sin_a * dist
            map_x, map_y = int(x), int(y)
            if map_x < 0 or map_x >= w or map_y < 0 or map_y >= h:
                hit_wall = True
                break
            if grid[map_y][map_x] == 1:   # 是墙
                hit_wall = True
                break
        # 修正鱼眼畸变
        corrected_dist = dist * math.cos(ray_angle - angle)
        result.append((corrected_dist, hit_wall))
    return result

def render_frame(grid, w, h, px, py, angle, term_h=30):
    """根据射线结果生成彩色字符串，用于终端输出"""
    rays = cast_rays(grid, w, h, px, py, angle)
    lines = []
    # 计算每列墙高（占终端行数）
    for row in range(term_h):
        line = ""
        for col, (dist, hit) in enumerate(rays):
            if not hit or dist < 0.1:
                # 水面
                line += BLUE_BG + " " + RESET
                continue
            # 墙高度映射：距离越近，墙越高
            wall_height = WALL_HEIGHT_FACTOR / max(dist, 0.1)
            wall_height = min(wall_height, term_h)
            # 当前行在屏幕中的位置
            screen_y = term_h - row - 1
            if screen_y < wall_height / 2:
                # 墙的上半部分（天空/阴影）
                if screen_y < wall_height / 4:
                    line += GRAY_BG + " " + RESET
                else:
                    line += DARK_BG + " " + RESET
            else:
                # 墙的下半部分或水面
                if screen_y < wall_height * 0.75:
                    line += GRAY_BG + " " + RESET
                else:
                    line += BLUE_BG + " " + RESET  # 接近水面反射
        lines.append(line)
    return "\n".join(lines)

# ==================== 主游戏循环 ====================
def main():
    # 生成迷宫
    print("正在生成复杂蓝色水道...")
    grid, mw, mh, (start_x, start_y) = generate_maze(60, 60)
    px, py = start_x + 0.5, start_y + 0.5  # 浮点坐标
    angle = random.random() * 2 * math.pi

    # 终端设置
    os.system("")  # 启用ANSI转义
    print(CLEAR, end="")
    print("第一人称走蓝迷宫 — WASD移动, Q退出", end="\r\n")
    input("按回车开始...")

    term_h = os.get_terminal_size().lines - 2
    term_h = max(term_h, 20)

    try:
        while True:
            # 渲染并输出
            frame = render_frame(grid, mw, mh, px, py, angle, term_h)
            sys.stdout.write(CLEAR)
            sys.stdout.write("WASD移动 | Q退出 | 当前坐标: ({:.1f},{:.1f})\n".format(px, py))
            sys.stdout.write(frame)
            sys.stdout.flush()

            # 输入处理（需要回车确认，简单实现）
            cmd = input().strip().lower()
            if cmd == 'q':
                break
            # 移动
            move_speed = 0.3
            old_px, old_py = px, py
            if 'w' in cmd:
                px += math.cos(angle) * move_speed
                py += math.sin(angle) * move_speed
            if 's' in cmd:
                px -= math.cos(angle) * move_speed
                py -= math.sin(angle) * move_speed
            if 'a' in cmd:
                # 左移（垂直于视线）
                px -= math.sin(angle) * move_speed
                py += math.cos(angle) * move_speed
            if 'd' in cmd:
                px += math.sin(angle) * move_speed
                py -= math.cos(angle) * move_speed
            # 旋转
            if 'j' in cmd:
                angle -= 0.2
            if 'l' in cmd:
                angle += 0.2
            # 碰撞检测：检查新位置是否为墙
            map_x, map_y = int(px), int(py)
            if 0 <= map_x < mw and 0 <= map_y < mh:
                if grid[map_y][map_x] == 1:
                    px, py = old_px, old_py  # 撞墙回退
            else:
                px, py = old_px, old_py
    except KeyboardInterrupt:
        pass
    finally:
        print(CLEAR + RESET + "迷宫之旅结束。")

if __name__ == "__main__":
    main()
