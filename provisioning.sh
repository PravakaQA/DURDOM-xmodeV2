#!/bin/bash
set -e

echo "🚀 Provisioning FINAL FULL TEMPLATE started..."

apt-get update && apt-get install -y git wget curl aria2 python3-pip unzip ffmpeg

PIP="/venv/main/bin/pip"
PY="/venv/main/bin/python"
COMFY="/workspace/ComfyUI"
MODELS="$COMFY/models"
NODES="$COMFY/custom_nodes"
WORKFLOWS="$COMFY/user/default/workflows"

MS_CACHE_ROOT="/root/.cache/modelscope"
WS_CACHE_ROOT="/workspace/.cache/modelscope"

echo "📦 Using pip: $PIP"
echo "🐍 Using python: $PY"

clone_or_update() {
  local repo_url="$1"
  local target_dir="$2"

  if [ -d "$target_dir/.git" ]; then
    echo "🔄 Updating $(basename "$target_dir")"
    git -C "$target_dir" pull --rebase || true
  else
    echo "📥 Cloning $(basename "$target_dir")"
    git clone "$repo_url" "$target_dir" || true
  fi
}

download_if_missing() {
  local out_dir="$1"
  local out_name="$2"
  local url="$3"

  mkdir -p "$out_dir"

  if [ -f "$out_dir/$out_name" ]; then
    echo "✅ Exists: $out_dir/$out_name"
  else
    echo "📥 Downloading: $out_name"
    aria2c -x 16 -s 16 --continue=true --dir="$out_dir" --out="$out_name" "$url" || true
  fi
}

# ====================== CUSTOM NODES ======================
echo ""
echo "📦 Installing custom nodes..."
mkdir -p "$NODES"
cd "$NODES"

clone_or_update "https://github.com/ZhiHui6/zhihui_nodes_comfyui.git" "$NODES/zhihui_nodes_comfyui"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git" "$NODES/ComfyUI-Impact-Subpack"
clone_or_update "https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git" "$NODES/ComfyUI-SeedVR2_VideoUpscaler"
clone_or_update "https://github.com/Azornes/Comfyui-Resolution-Master.git" "$NODES/Comfyui-Resolution-Master"
clone_or_update "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git" "$NODES/ComfyUI-Custom-Scripts"
clone_or_update "https://github.com/chrisgoringe/cg-use-everywhere.git" "$NODES/cg-use-everywhere"
clone_or_update "https://github.com/ClownsharkBatwing/RES4LYF.git" "$NODES/RES4LYF"
clone_or_update "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" "$NODES/ComfyUI-WanVideoWrapper"
clone_or_update "https://github.com/kijai/ComfyUI-WanAnimatePreprocess.git" "$NODES/ComfyUI-WanAnimatePreprocess"
clone_or_update "https://github.com/kijai/ComfyUI-KJNodes.git" "$NODES/ComfyUI-KJNodes"
clone_or_update "https://github.com/rgthree/rgthree-comfy.git" "$NODES/rgthree-comfy"
clone_or_update "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" "$NODES/ComfyUI-Impact-Pack"
clone_or_update "https://github.com/teskor-hub/comfyui-teskors-utils.git" "$NODES/comfyui-teskors-utils"
clone_or_update "https://github.com/PozzettiAndrea/ComfyUI-SAM3.git" "$NODES/ComfyUI-SAM3"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" "$NODES/ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/ClownsharkBatwing/ComfyUI-ClownsharK.git" "$NODES/ComfyUI-ClownsharK"
clone_or_update "https://github.com/cubiq/ComfyUI_essentials.git" "$NODES/ComfyUI_essentials"
clone_or_update "https://github.com/LeonQ8/ComfyUI-Dynamic-Lora-Scheduler.git" "$NODES/ComfyUI-Dynamic-Lora-Scheduler"
clone_or_update "https://github.com/PGCRT/CRT-Nodes.git" "$NODES/CRT-Nodes"

echo ""
echo "📦 Installing Python dependencies..."
$PIP install --upgrade pip setuptools wheel
$PIP install --upgrade --force-reinstall opencv-python opencv-python-headless
$PIP install -U \
  ultralytics \
  onnx \
  onnxruntime-gpu \
  segment-anything \
  safetensors \
  huggingface_hub \
  bitsandbytes \
  transformers \
  accelerate \
  sentencepiece \
  modelscope \
  scipy \
  color-matcher \
  spandrel \
  pedalboard \
  wordcloud \
  librosa \
  imageio-ffmpeg || true

for dir in "$NODES"/*; do
  if [ -f "$dir/requirements.txt" ]; then
    echo "→ Installing requirements for $(basename "$dir")"
    $PIP install -r "$dir/requirements.txt" || true
  fi
done

# ====================== WORKFLOWS ======================
echo ""
echo "📂 Copying workflows..."
mkdir -p "$WORKFLOWS"
cp /workspace/provisioning/*.json "$WORKFLOWS/" 2>/dev/null || echo "⚠️ No workflow json files found in /workspace/provisioning"

# ====================== MODEL DIRS ======================
echo ""
echo "📁 Creating model directories..."
mkdir -p \
  "$MODELS/diffusion_models" \
  "$MODELS/unet" \
  "$MODELS/checkpoints" \
  "$MODELS/vae" \
  "$MODELS/text_encoders" \
  "$MODELS/clip" \
  "$MODELS/clip_vision" \
  "$MODELS/loras" \
  "$MODELS/controlnet" \
  "$MODELS/detection" \
  "$MODELS/ultralytics/bbox" \
  "$MODELS/onnx" \
  "$MODELS/sams" \
  "$MODELS/sam" \
  "$MODELS/LLM"

mkdir -p "$MS_CACHE_ROOT" "$WS_CACHE_ROOT"
ln -sfn "$MS_CACHE_ROOT" "$WS_CACHE_ROOT" || true

# ====================== NEW TEMPLATE / Z-IMAGE STACK ======================
echo ""
echo "🚀 Downloading NEW TEMPLATE core models..."

download_if_missing "$MODELS/diffusion_models" "z_image_turbo_bf16.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/z_image_turbo_bf16.safetensors"

download_if_missing "$MODELS/vae" "mo_vae.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/vae.safetensors"

download_if_missing "$MODELS/clip_vision" "klip_vision.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/klip_vision.safetensors"

download_if_missing "$MODELS/text_encoders" "text_enc.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/text_enc.safetensors"

download_if_missing "$MODELS/loras" "bueno-z_000001250.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/bueno-z_000001250.safetensors"

# ====================== COMPATIBILITY FIXES ======================
echo ""
echo "🛠️ Applying compatibility fixes..."

# VAE compatibility
ln -sfn "$MODELS/vae/mo_vae.safetensors" "$MODELS/vae/ae.safetensors" || true

# Text encoder compatibility
ln -sfn "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/clip/text_enc.safetensors" || true

# Some loaders expect qwen_3_4b.safetensors by exact filename
if [ ! -f "$MODELS/text_encoders/qwen_3_4b.safetensors" ]; then
  cp "$MODELS/text_encoders/text_enc.safetensors" "$MODELS/text_encoders/qwen_3_4b.safetensors" || true
fi
ln -sfn "$MODELS/text_encoders/qwen_3_4b.safetensors" "$MODELS/clip/qwen_3_4b.safetensors" || true

# Extra alias if loader checks checkpoint folder style lists
ln -sfn "$MODELS/diffusion_models/z_image_turbo_bf16.safetensors" "$MODELS/unet/z_image_turbo_bf16.safetensors" || true

# Optional alternate name seen in dumps
ln -sfn "$MODELS/diffusion_models/z_image_turbo_bf16.safetensors" "$MODELS/diffusion_models/z-image-turbo-fp8-e4m3fn.safetensors" || true

# ====================== QWEN3-VL-4B-INSTRUCT ======================
echo ""
echo "📥 Downloading Qwen3-VL-4B-Instruct via ModelScope..."
export MODELSCOPE_CACHE="$MS_CACHE_ROOT"

$PY - <<'PY'
import os
from modelscope import snapshot_download

cache_root = os.environ["MODELSCOPE_CACHE"]
try:
    model_dir = snapshot_download(model_id="Qwen/Qwen3-VL-4B-Instruct", cache_dir=cache_root)
    print(f"✅ ModelScope downloaded to: {model_dir}")
except Exception as e:
    print(f"⚠️ ModelScope download failed: {e}")
PY

if [ -d "$MS_CACHE_ROOT/hub/Qwen/Qwen3-VL-4B-Instruct" ]; then
  ln -sfn "$MS_CACHE_ROOT/hub/Qwen/Qwen3-VL-4B-Instruct" "$MODELS/LLM/Qwen3-VL-4B-Instruct"
fi

# ====================== LEGACY WAN / ANIMATOR SUPPORT ======================
echo ""
echo "🎬 Downloading legacy Wan / Animator compatibility models..."

download_if_missing "$MODELS/diffusion_models" "WanModel.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"

download_if_missing "$MODELS/vae" "Wan2_1_VAE_bf16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

# keep old expected name too
ln -sfn "$MODELS/vae/Wan2_1_VAE_bf16.safetensors" "$MODELS/vae/mo_vae_legacy.safetensors" || true

download_if_missing "$MODELS/clip_vision" "clip_vision_h.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

download_if_missing "$MODELS/clip" "umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download_if_missing "$MODELS/loras" "WanPusa.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanPusa.safetensors"

download_if_missing "$MODELS/loras" "WanFun.reworked.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/loras/WanFun.reworked.safetensors"

download_if_missing "$MODELS/loras" "wan.reworked.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/wan.reworked.safetensors"

download_if_missing "$MODELS/loras" "light.safetensors" \
  "https://huggingface.co/wdsfdsdf/OFMHUB/resolve/main/light.safetensors"

# ====================== ONNX / DETECTORS ======================
echo ""
echo "🧠 Downloading ONNX and detector models..."

download_if_missing "$MODELS/onnx" "yolov10m.onnx" \
  "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"

download_if_missing "$MODELS/onnx" "vitpose_h_wholebody_model.onnx" \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"

download_if_missing "$MODELS/onnx" "vitpose_h_wholebody_data.bin" \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"

# mirror ONNX files into detection-compatible places if needed
ln -sfn "$MODELS/onnx/yolov10m.onnx" "$MODELS/detection/yolov10m.onnx" || true
ln -sfn "$MODELS/onnx/vitpose_h_wholebody_model.onnx" "$MODELS/detection/vitpose_h_wholebody_model.onnx" || true
ln -sfn "$MODELS/onnx/vitpose_h_wholebody_data.bin" "$MODELS/detection/vitpose_h_wholebody_data.bin" || true

download_if_missing "$MODELS/controlnet" "Wan21_Uni3C_controlnet_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors"

download_if_missing "$MODELS/sams" "sam_vit_b_01ec64.pth" \
  "https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth"
ln -sfn "$MODELS/sams/sam_vit_b_01ec64.pth" "$MODELS/sam/sam_vit_b_01ec64.pth" || true

download_if_missing "$MODELS/ultralytics/bbox" "face_yolov8s.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt"

download_if_missing "$MODELS/ultralytics/bbox" "hand_yolov8s.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt"

# Extra names seen in explorer / older flows
download_if_missing "$MODELS/ultralytics/bbox" "assdetailer.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt"

download_if_missing "$MODELS/ultralytics/bbox" "Eyeful_v2-Paired.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt"

download_if_missing "$MODELS/ultralytics/bbox" "Eyes.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt"

download_if_missing "$MODELS/ultralytics/bbox" "FacesV1.pt" \
  "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8s.pt"

# ====================== FINAL PERMISSIONS / CACHE ======================
echo ""
echo "🧹 Finalizing..."
find "$COMFY" -type d -exec chmod 755 {} \; || true
find "$COMFY" -type f -exec chmod 644 {} \; || true

echo ""
echo "✅ FINAL TEMPLATE SETUP READY"
echo ""
echo "Проверь после перезапуска:"
echo "  - text_encoders/qwen_3_4b.safetensors"
echo "  - vae/ae.safetensors"
echo "  - diffusion_models/z_image_turbo_bf16.safetensors"
echo "  - loras/bueno-z_000001250.safetensors"
echo "  - onnx/yolov10m.onnx"
echo "  - onnx/vitpose_h_wholebody_model.onnx"
echo "  - controlnet/Wan21_Uni3C_controlnet_fp16.safetensors"
echo ""
echo "Если workflow всё равно ругнётся на конкретное имя файла — пришли exact error,"
echo "и я добью уже адресно без гаданий."
