MODDIR=${0%/*}

cd $MODDIR
chmod 777 "YHyc"

echo "开始监控 YHyc 进程..."

while true; do
    # 检测 YHyc 进程是否在运行
    if pgrep -f "YHyc" > /dev/null; then
        echo "YHyc 进程正在运行，监控完成"
        exit 0
    else
        echo "YHyc 未运行，尝试启动..."
        # 执行 YHyc
        ./YHyc &
        echo "已启动 YHyc，等待 5 秒后检查..."
        sleep 5
    fi
done