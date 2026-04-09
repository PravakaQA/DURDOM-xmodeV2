#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - FULL AUTO FIXED started..."

apt-get update && apt-get install -y git wget aria2 python3-pip unzip

cd /workspace/ComfyUI/custom_nodes

# ←←←←← САМАЯ ВАЖНАЯ СТРОКА ←←←←←
PIP="/venv/main/bin/pip"
echo "📦 Используем venv pip: $PIP"

echo "📥 Клонируем ВСЕ custom nodes для XMODE (PHOTO)..."

git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/chrisgoringe/cg-use-everywhere.git
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/AlnVFX/ComfyUI-SeedVR2.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
git clone https://github.com/Azores/ComfyUI-Resolution-Master.git
git clone https://github.com/crt-nodes/CRT-Nodes.git
git clone https://github.com/Matteo/ComfyUI_essentials.git
git clone https://github.com/RES4LYF/RES4LYF.git
git clone https://github.com/ZhiHui6/zhihui_nodes_comfyui.git

echo "📦 Устанавливаем все зависимости в venv..."

# Сначала OpenCV (самая частая причина ошибок cv2)
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless

# Теперь все requirements.txt из нод
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Устанавливаем зависимости для $dir"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

echo "📂 Копируем workflow..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /workspace/provisioning/xmode_public.json /workspace/ComfyUI/user/default/workflows/xmode_public.json 2>/dev/null || echo "⚠️ xmode_public.json не найден в /workspace/provisioning/"

echo "✅ XMODE (PHOTO) ПОЛНОСТЬЮ ГОТОВ!"
echo "Workflow: /workspace/ComfyUI/user/default/workflows/xmode_public.json"
echo "После перезапуска ComfyUI зайди в Manager → Check Missing (должно быть чисто)"
