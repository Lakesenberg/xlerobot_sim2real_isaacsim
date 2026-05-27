"""Scene asset configurations for XLeRobot environments."""

import isaaclab.sim as sim_utils
from isaaclab.assets import AssetBaseCfg

from xlerobot_tasks.utils.constant import ASSETS_ROOT

# --- Table with Cube scene ---

TABLE_WITH_CUBE_USD_PATH = f"{ASSETS_ROOT}/scenes/table_with_cube/scene.usd"

TABLE_WITH_CUBE_CFG = AssetBaseCfg(
    prim_path="{ENV_REGEX_NS}/Scene",
    spawn=sim_utils.UsdFileCfg(usd_path=TABLE_WITH_CUBE_USD_PATH),
)

# --- Lightwheel Loft scene ---

LOFT_USD_PATH = f"{ASSETS_ROOT}/scenes/lightwheel_loft/LW_Loft.usd"

LOFT_CFG = AssetBaseCfg(
    prim_path="{ENV_REGEX_NS}/Scene",
    spawn=sim_utils.UsdFileCfg(usd_path=LOFT_USD_PATH),
)
