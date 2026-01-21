import numpy as np
import cv2

# --- Colorblind simulation matrices ---
PROTANOPIA = np.array([
    [0.56667, 0.43333, 0.00000],
    [0.55833, 0.44167, 0.00000],
    [0.00000, 0.24167, 0.75833]
])

DEUTERANOPIA = np.array([
    [0.625, 0.375, 0.000],
    [0.700, 0.300, 0.000],
    [0.000, 0.300, 0.700]
])

TRITANOPIA = np.array([
    [0.950, 0.050, 0.000],
    [0.000, 0.433, 0.567],
    [0.000, 0.475, 0.525]
])


# --- Gamma correction helpers ---
def linearize(img):
    img = img / 255.0
    return np.where(img <= 0.04045,
                    img / 12.92,
                    ((img + 0.055) / 1.055) ** 2.4)


def delinearize(img):
    return np.where(img <= 0.0031308,
                    img * 12.92,
                    1.055 * (img ** (1 / 2.4)) - 0.055)


# --- Daltonization ---
def daltonize(image_bgr, defect):
    # Convert BGR → RGB
    image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    img = linearize(image.astype(np.float32))

    if defect == "protanopia":
        sim = img @ PROTANOPIA.T
        error = img - sim
        correction = np.zeros_like(img)
        # Distribute Red error primarily to Blue for better visibility
        correction[..., 1] = error[..., 0] * 0.7  # Green
        correction[..., 2] = error[..., 0] * 1.0  # Blue (Stronger)

    elif defect == "deuteranopia":
        sim = img @ DEUTERANOPIA.T
        error = img - sim
        correction = np.zeros_like(img)
        # Distribute Green error primarily to Red
        correction[..., 0] = error[..., 1] * 1.0  # Red (Stronger)
        correction[..., 2] = error[..., 1] * 0.7  # Blue

    elif defect == "tritanopia":
        sim = img @ TRITANOPIA.T
        error = img - sim
        correction = np.zeros_like(img)
        # Distribute Blue error primarily to Green for distinction
        correction[..., 0] = error[..., 2] * 0.7  # Red
        correction[..., 1] = error[..., 2] * 1.0  # Green (Stronger)

    else:
        return image_bgr

    # Apply correction gently (natural look)
    out = img + correction * 1.5
    out = np.clip(out, 0, 1)

    out = (delinearize(out) * 255).astype(np.uint8)

    # Convert RGB → BGR
    return cv2.cvtColor(out, cv2.COLOR_RGB2BGR)
