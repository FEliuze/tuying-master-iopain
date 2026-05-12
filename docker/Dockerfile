# 基础镜像
FROM python:3.10-slim

# ===== 更稳健的阿里云源配置方法 =====
# 1. 删除所有默认的源列表（如果存在）
# 2. 直接写入阿里云镜像源（使用 deb.debian.org 的官方结构映射）
RUN rm -f /etc/apt/sources.list.d/* && \
    echo "deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list

# 设置环境变量，使用 Hugging Face 国内镜像源
ENV HF_ENDPOINT=https://hf-mirror.com
ENV XDG_CACHE_HOME=/opt/iopaint-cache

# 更新源并安装依赖包
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 安装 IOPaint（使用清华源加速）
RUN pip install iopaint -i https://pypi.tuna.tsinghua.edu.cn/simple

# 创建缓存目录
RUN mkdir -p /opt/iopaint-cache && chmod 777 /opt/iopaint-cache

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["iopaint", "start", "--model=lama", "--device=cpu", "--host=0.0.0.0", "--port=8000"]
