# -*- coding: utf-8 -*-

from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.patches import Circle


AXIS_LENGTH = 2.4
X_COLOR = "#e53935"
Y_COLOR = "#43a047"
Z_COLOR = "#1e88e5"
OUTPUT_PATH = Path(__file__).resolve().parent / "output" / "handedness.png"


def configure_chinese_font():
    """优先使用系统中已安装的中文字体，避免标题和说明显示为方框。"""
    candidates = (
        "Microsoft YaHei",
        "SimHei",
        "Noto Sans CJK SC",
        "Source Han Sans SC",
        "PingFang SC",
        "WenQuanYi Micro Hei",
    )
    installed_fonts = {font.name for font in font_manager.fontManager.ttflist}
    for font_name in candidates:
        if font_name in installed_fonts:
            mpl.rcParams["font.sans-serif"] = [font_name, "DejaVu Sans"]
            break
    mpl.rcParams["axes.unicode_minus"] = False


def draw_axis(ax, end, label, color):
    ax.annotate(
        "",
        xy=end,
        xytext=(0, 0),
        arrowprops={
            "arrowstyle": "-|>",
            "color": color,
            "linewidth": 3,
            "mutation_scale": 18,
            "shrinkA": 0,
            "shrinkB": 0,
        },
        zorder=2,
    )
    label_offset = (0.14, -0.05) if end[0] else (-0.12, 0.16)
    ax.text(
        end[0] + label_offset[0],
        end[1] + label_offset[1],
        label,
        color=color,
        fontsize=14,
        fontweight="bold",
        ha="center",
        va="center",
    )


def draw_z_direction(ax, points_outward):
    """用圆点/叉号表示垂直屏幕向外/向内的 +Z 方向。"""
    marker_radius = 0.18
    ax.add_patch(
        Circle(
            (0, 0),
            marker_radius,
            facecolor="white",
            edgecolor=Z_COLOR,
            linewidth=3,
            zorder=4,
        )
    )

    if points_outward:
        ax.add_patch(Circle((0, 0), 0.055, facecolor=Z_COLOR, edgecolor="none", zorder=5))
        direction_text = "垂直屏幕向外（朝向观察者）"
    else:
        cross_size = 0.105
        ax.plot(
            [-cross_size, cross_size],
            [-cross_size, cross_size],
            color=Z_COLOR,
            linewidth=3,
            solid_capstyle="round",
            zorder=5,
        )
        ax.plot(
            [-cross_size, cross_size],
            [cross_size, -cross_size],
            color=Z_COLOR,
            linewidth=3,
            solid_capstyle="round",
            zorder=5,
        )
        direction_text = "垂直屏幕向内（远离观察者）"

    ax.text(0.24, -0.24, "+Z", color=Z_COLOR, fontsize=14, fontweight="bold")
    ax.text(
        1.18,
        -0.53,
        direction_text,
        color="#455a64",
        fontsize=10.5,
        ha="center",
        va="center",
    )


def draw_coordinate_system(ax, title, points_outward, equation):
    draw_axis(ax, (AXIS_LENGTH, 0), "+X", X_COLOR)
    draw_axis(ax, (0, AXIS_LENGTH), "+Y", Y_COLOR)
    draw_z_direction(ax, points_outward)

    ax.text(-0.18, -0.30, "O", color="#37474f", fontsize=11, ha="center")
    ax.text(
        1.18,
        2.82,
        equation,
        color="#263238",
        fontsize=13,
        ha="center",
        va="center",
    )
    ax.set_title(title, fontsize=16, fontweight="bold", pad=18, color="#263238")
    ax.set_xlim(-0.65, 3.0)
    ax.set_ylim(-0.75, 3.05)
    ax.set_aspect("equal", adjustable="box")
    ax.axis("off")


def main():
    configure_chinese_font()
    fig, axes = plt.subplots(1, 2, figsize=(11, 5.5), facecolor="#f7f9fb")

    for ax in axes:
        ax.set_facecolor("#f7f9fb")

    draw_coordinate_system(
        axes[0],
        "右手坐标系（RHS）",
        points_outward=True,
        equation=r"$\mathbf{X}\times\mathbf{Y}=\mathbf{Z}$",
    )
    draw_coordinate_system(
        axes[1],
        "左手坐标系（LHS）",
        points_outward=False,
        equation=r"$\mathbf{X}\times\mathbf{Y}=-\mathbf{Z}$",
    )

    fig.suptitle(
        "左右手坐标系标准示意图",
        fontsize=19,
        fontweight="bold",
        color="#102027",
        y=0.98,
    )
    fig.text(
        0.5,
        0.035,
        "红色：X 轴    绿色：Y 轴    蓝色：Z 轴",
        ha="center",
        fontsize=11,
        color="#546e7a",
    )
    fig.subplots_adjust(left=0.06, right=0.96, bottom=0.12, top=0.82, wspace=0.28)

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_PATH, dpi=180, bbox_inches="tight", facecolor=fig.get_facecolor())
    print(f"示意图已保存至：{OUTPUT_PATH}")
    plt.show()


if __name__ == "__main__":
    main()
