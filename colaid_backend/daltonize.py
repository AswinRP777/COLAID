import numpy as np
import cv2
import gc

# --- Colorblind simulation matrices (float32 to save memory) ---
PROTANOPIA = np.array([
    [0.56667, 0.43333, 0.00000],
    [0.55833, 0.44167, 0.00000],
    [0.00000, 0.24167, 0.75833]
], dtype=np.float32)

DEUTERANOPIA = np.array([
    [0.625, 0.375, 0.000],
    [0.700, 0.300, 0.000],
    [0.000, 0.300, 0.700]
], dtype=np.float32)

TRITANOPIA = np.array([
    [0.950, 0.050, 0.000],
    [0.000, 0.433, 0.567],
    [0.000, 0.475, 0.525]
], dtype=np.float32)

# Maximum image dimension to prevent OOM on free-tier hosting (512MB)
MAX_DIMENSION = 1920


# --- Gamma correction helpers ---
def linearize(img):
    img = img / 255.0
    return np.where(img <= 0.04045,
                    img / 12.92,
                    ((img + 0.055) / 1.055) ** 2.4).astype(np.float32)


def delinearize(img):
    return np.where(img <= 0.0031308,
                    img * 12.92,
                    1.055 * (img ** (1 / 2.4)) - 0.055).astype(np.float32)


def resize_if_needed(img):
    """Resize image if it exceeds MAX_DIMENSION to prevent memory overflow."""
    h, w = img.shape[:2]
    if max(h, w) > MAX_DIMENSION:
        scale = MAX_DIMENSION / max(h, w)
        new_w, new_h = int(w * scale), int(h * scale)
        print(f"⚠️ Resizing image from {w}x{h} to {new_w}x{new_h} to save memory")
        return cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
    return img


# --- Daltonization ---
def daltonize(image_bgr, defect):
    # Resize to cap memory usage
    image_bgr = resize_if_needed(image_bgr)

    # Convert BGR → RGB
    image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    del image_bgr  # free original
    img = linearize(image.astype(np.float32))
    del image  # free RGB copy

    if defect == "protanopia":
        sim = img @ PROTANOPIA.T
        error = img - sim
        del sim
        correction = np.zeros_like(img)
        correction[..., 1] = error[..., 0] * 0.7  # Green
        correction[..., 2] = error[..., 0] * 1.0  # Blue (Stronger)
        del error

    elif defect == "deuteranopia":
        sim = img @ DEUTERANOPIA.T
        error = img - sim
        del sim
        correction = np.zeros_like(img)
        correction[..., 0] = error[..., 1] * 1.0  # Red (Stronger)
        correction[..., 2] = error[..., 1] * 0.7  # Blue
        del error

    elif defect == "tritanopia":
        sim = img @ TRITANOPIA.T
        error = img - sim
        del sim
        correction = np.zeros_like(img)
        correction[..., 0] = error[..., 2] * 0.7  # Red
        correction[..., 1] = error[..., 2] * 1.0  # Green (Stronger)
        del error

    else:
        return image_bgr

    # Apply correction gently (natural look)
    out = img + correction * 1.5
    del img, correction
    np.clip(out, 0, 1, out=out)  # in-place clip

    out = (delinearize(out) * 255).astype(np.uint8)

    gc.collect()  # force garbage collection

    # Convert RGB → BGR
    return cv2.cvtColor(out, cv2.COLOR_RGB2BGR)
