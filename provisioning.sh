#!/bin/bash
echo "🚀 Provisioning X MODE (PHOTO) started..."

# Обновляем систему
apt-get update && apt-get install -y git wget aria2 python3-pip unzip

# Переходим в custom_nodes
#!/bin/bash
echo "🚀 Provisioning X MODE (PHOTO) started..."

apt-get update && apt-get install -y git wget aria2 python3-pip unzip

cd /workspace/ComfyUI/custom_nodes

echo "📦 Клонируем все custom nodes для X Mode..."

git clone https://github.com/rgthree/rgthree-comfy.git
git clone https://github.com/kijai/ComfyUI-KJNodes.git
git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git
git clone https://github.com/teskor-hub/comfyui-teskors-utils.git
git clone https://github.com/ComfyUI-Research/ComfyUI-Resolution-Master.git
git clone https://github.com/PozzettiAndrea/ComfyUI-SAM3.git
git clone https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git

echo "📦 Устанавливаем зависимости..."
for dir in */; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ $dir"
    pip install -r "$dir/requirements.txt" --no-deps || true
  fi
done

echo "📂 Копируем workflow..."
mkdir -p /workspace/ComfyUI/user/default/workflows
cp /provisioning/xmode.json /workspace/ComfyUI/user/default/workflows/xmode.json

echo "✅ X MODE (PHOTO) ГОТОВ!"
echo "Workflow находится в: /workspace/ComfyUI/user/default/workflows/xmode.json"