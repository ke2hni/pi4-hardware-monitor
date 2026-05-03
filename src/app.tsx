async function readThermalPatch(): Promise<MonitorPatch> {
    const cmd = `
      CPU_TEMP=""

      if [ -r /sys/class/hwmon/hwmon0/temp1_input ]; then
        CPU_TEMP=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null || true)
      fi

      if [ -z "$CPU_TEMP" ]; then
        CPU_TEMP=$(vcgencmd measure_temp 2>/dev/null | sed "s/.*=//; s/'C//" | awk 'NF {printf "%d", $1 * 1000}' || true)
      fi

      if [ -n "$CPU_TEMP" ]; then
        echo "CPU=$CPU_TEMP"
      fi

      PMIC_TEMP=$(vcgencmd measure_temp pmic 2>/dev/null | sed "s/.*=//; s/'C//" | awk 'NF {printf "%d", $1 * 1000}' || true)
      if [ -n "$PMIC_TEMP" ]; then
        echo "PMIC_TEMP=$PMIC_TEMP"
      fi

      FAN_VALUE=""
      PWM_VALUE=""
      FAN_FOUND=0
      PWM_FOUND=0

      for HWMON_DIR in /sys/class/hwmon/hwmon*; do
        [ -d "$HWMON_DIR" ] || continue

        if [ "$FAN_FOUND" -eq 0 ]; then
          for FAN_PATH in "$HWMON_DIR"/fan*_input; do
            [ -r "$FAN_PATH" ] || continue
            FAN_VALUE=$(cat "$FAN_PATH" 2>/dev/null || true)
            if [ -n "$FAN_VALUE" ]; then
              FAN_FOUND=1
              break
            fi
          done
        fi

        if [ "$PWM_FOUND" -eq 0 ]; then
          for PWM_PATH in "$HWMON_DIR"/pwm[0-9]*; do
            [ -r "$PWM_PATH" ] || continue
            case "$PWM_PATH" in
              *_enable) continue ;;
            esac
            PWM_VALUE=$(cat "$PWM_PATH" 2>/dev/null || true)
            if [ -n "$PWM_VALUE" ]; then
              PWM_FOUND=1
              break
            fi
          done
        fi

        if [ "$FAN_FOUND" -eq 1 ] && [ "$PWM_FOUND" -eq 1 ]; then
          break
        fi
      done

      [ "$FAN_FOUND" -eq 1 ] && echo "FAN=$FAN_VALUE"
      [ "$PWM_FOUND" -eq 1 ] && echo "PWM=$PWM_VALUE"
      { [ "$FAN_FOUND" -eq 1 ] || [ "$PWM_FOUND" -eq 1 ]; } && echo "FAN_PRESENT=1"

      exit 0
    `;

    const out = await cockpit.spawn(["sh", "-c", cmd], { err: "out" });
    const data = parseKeyValueOutput(out);

    return {
        thermal: {
            cpuTemp: formatTemp(data.CPU || ""),
            pmicTemp: data.PMIC_TEMP ? formatTemp(data.PMIC_TEMP) : "--",
            fanRpm: data.FAN ? formatRpm(data.FAN) : "--",
            fanPwm: data.PWM ? formatPercentFromPwm(data.PWM) : "--",
        },
        boot: {
            fanPresent: formatYesNoFromZeroOne(data.FAN_PRESENT || "0"),
        },
    };
}
