#!/bin/bash
echo "🚀 Provisioning XMODE (PHOTO) - FULL AUTO started..."

apt-get update && apt-get install -y git wget aria2 python3-pip unzip

cd /workspace/ComfyUI/custom_nodes

echo "📥 Клонируем ВСЕ недостающие ноды..."

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
git clone https://github.com/ZhiHui6/zhihui_nodes_comfyui.git   # ← это Qwen3VLBasic

echo "📦 Устанавливаем все зависимости..."
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ $dir"
    pip install -r "$dir/requirements.txt" --no-deps || true
  fi
done

echo "📂 Копируем workflow..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /workspace/provisioning/xmode_public.json /workspace/ComfyUI/user/default/workflows/xmode_public.json

echo "✅ XMODE ПОЛНОСТЬЮ ГОТОВ!"
echo "Workflow: /workspace/ComfyUI/user/default/workflows/xmode_public.json"
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /provisioning/xmode.json /workspace/ComfyUI/user/default/workflows/xmode.json

echo "✅ X MODE (PHOTO) ГОТОВ!"
echo "Workflow находится в: /workspace/ComfyUI/user/default/workflows/xmode.json"
