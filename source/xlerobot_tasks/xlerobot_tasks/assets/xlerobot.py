"""XLeRobot dual-arm mobile manipulator articulation configuration."""

import isaaclab.sim as sim_utils
from isaaclab.actuators import ImplicitActuatorCfg
from isaaclab.assets.articulation import ArticulationCfg

from xlerobot_tasks.utils.constant import ASSETS_ROOT

XLEROBOT_USD_PATH = f"{ASSETS_ROOT}/robots/xlerobot/xlerobot.usd"

XLEROBOT_CFG = ArticulationCfg(
    spawn=sim_utils.UsdFileCfg(
        usd_path=XLEROBOT_USD_PATH,
        activate_contact_sensors=False,
        rigid_props=sim_utils.RigidBodyPropertiesCfg(
            disable_gravity=False,
            max_depenetration_velocity=5.0,
        ),
        articulation_props=sim_utils.ArticulationRootPropertiesCfg(
            enabled_self_collisions=False,
            solver_position_iteration_count=32,
            solver_velocity_iteration_count=1,
            fix_root_link=True,
        ),
    ),
    init_state=ArticulationCfg.InitialStateCfg(
        pos=(0.0, 0.0, 0.0),
        rot=(1.0, 0.0, 0.0, 0.0),
        joint_pos={
            # Right arm
            "Rotation": 0.0,
            "Pitch": 0.0,
            "Elbow": 0.0,
            "Wrist_Pitch": 0.0,
            "Wrist_Roll": 0.0,
            "Jaw": 0.0,
            # Left arm
            "Rotation_2": 0.0,
            "Pitch_2": 0.0,
            "Elbow_2": 0.0,
            "Wrist_Pitch_2": 0.0,
            "Wrist_Roll_2": 0.0,
            "Jaw_2": 0.0,
            # Head
            "head_pan_joint": 0.0,
            "head_tilt_joint": 0.0,
            # Base (velocity-controlled, initial pos = 0)
            "root_x_axis_joint": 0.0,
            "root_y_axis_joint": 0.0,
            "root_z_rotation_joint": 0.0,
        },
    ),
    actuators={
        "right_arm": ImplicitActuatorCfg(
            joint_names_expr=["Rotation", "Pitch", "Elbow", "Wrist_Pitch", "Wrist_Roll"],
            effort_limit_sim=30,
            stiffness=40.0,
            damping=0.7,
        ),
        "right_gripper": ImplicitActuatorCfg(
            joint_names_expr=["Jaw"],
            effort_limit_sim=30,
            stiffness=4.0,
            damping=0.3,
        ),
        "left_arm": ImplicitActuatorCfg(
            joint_names_expr=["Rotation_2", "Pitch_2", "Elbow_2", "Wrist_Pitch_2", "Wrist_Roll_2"],
            effort_limit_sim=30,
            stiffness=40.0,
            damping=0.7,
        ),
        "left_gripper": ImplicitActuatorCfg(
            joint_names_expr=["Jaw_2"],
            effort_limit_sim=30,
            stiffness=4.0,
            damping=0.3,
        ),
        "head": ImplicitActuatorCfg(
            joint_names_expr=["head_pan_joint", "head_tilt_joint"],
            effort_limit_sim=10,
            stiffness=20.0,
            damping=0.5,
        ),
        "base": ImplicitActuatorCfg(
            joint_names_expr=["root_x_axis_joint", "root_y_axis_joint", "root_z_rotation_joint"],
            effort_limit_sim=100,
            stiffness=0.0,
            damping=10.0,
        ),
    },
)
