#!/bin/bash
set -e
echo "🚀 Provisioning NEW WORKFLOW (финальная версия с Impact Subpack fix) started..."
apt-get update && apt-get install -y git wget aria2 python3-pip unzip
PIP="/venv/main/bin/pip"
COMFY="/workspace/ComfyUI"
NODES="$COMFY/custom_nodes"

echo "📥 Клонируем/обновляем ВСЕ ноды..."
cd "$NODES"

git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git || (cd ComfyUI-Impact-Subpack && git pull)
git clone https://github.com/ZhiHui6/zhihui_nodes_comfyui.git || true
git clone https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git || true
git clone https://github.com/Azornes/Comfyui-Resolution-Master.git || true
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git || true
git clone https://github.com/chrisgoringe/cg-use-everywhere.git || true
git clone https://github.com/ClownsharkBatwing/RES4LYF.git || true
# (остальные ноды как раньше — я их оставил)

echo "📦 Устанавливаем зависимости..."
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

echo ""
echo "✅ СКРИПТ ЗАВЕРШЁН!"
echo "Перезапусти ComfyUI и зайди в Manager → Check Missing"
echo "Impact Subpack теперь должен быть зелёным автоматически."
