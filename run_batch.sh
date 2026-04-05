#!/bin/bash

module load cuda/11.7.0

GCC9=/opt/ohpc/pub/compiler/gcc/9.4.0/bin
export PATH=$GCC9:$PATH

WORKSPACE_DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$WORKSPACE_DIR/build/lib:/opt/ohpc/pub/unpackaged/apps/cuda/11.7.0/targets/x86_64-linux/lib:$LD_LIBRARY_PATH"
BINARY="$WORKSPACE_DIR/build/bin/VolumeVoronoiGPU"
INPUT_BASE="/groups/xguo/axk230084/experiments/MATStruct/input"
OUTPUT_DIR="/groups/xguo/axk230084/experiments/MATStruct/output"
LOG_DIR="$OUTPUT_DIR/logs"
SUMMARY_FILE="$LOG_DIR/summary.txt"
TIMEOUT=600

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

if [ ! -d "$INPUT_BASE" ]; then
    echo "ERROR: Input directory not found at $INPUT_BASE"
    exit 1
fi

total=0
success_cad=0
success_organic=0
failed=0
skipped=0

cad_success_files=()
organic_success_files=()
failed_files=()

for dir in "$INPUT_BASE"/*/; do
    [ -d "$dir" ] || continue

    input_file=$(find "$dir" -maxdepth 1 -name "*.msh" | head -1)

    if [ -z "$input_file" ]; then
        echo "[SKIP] No .msh file in: $dir"
        ((skipped++))
        continue
    fi

    folder_name="$(basename "$dir")"
    ((total++))
    log_file="$LOG_DIR/${folder_name}.log"
    > "$log_file"

    echo ""
    echo "[$total] Processing: $input_file"
    echo "----------------------------------------"

    # CAD mode
    {
        echo "## CAD MODE"
        echo "Input: $input_file"
        echo "Date:  $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } >> "$log_file"

    timeout "$TIMEOUT" "$BINARY" -i "$input_file" -d "$OUTPUT_DIR" >> "$log_file" 2>&1
    cad_exit=$?

    if [ $cad_exit -eq 0 ]; then
        ((success_cad++))
        cad_success_files+=("$input_file")
        echo "Exit code: 0 — OK" >> "$log_file"
        echo "  -> OK (CAD mode)"
        continue
    fi

    echo "Exit code: $cad_exit — FAILED" >> "$log_file"
    echo "  -> FAILED (CAD, exit $cad_exit), retrying with -o ..."

    # Organic mode
    {
        echo ""
        echo "## ORGANIC MODE (-o)"
        echo "Date:  $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } >> "$log_file"

    timeout "$TIMEOUT" "$BINARY" -i "$input_file" -o -d "$OUTPUT_DIR" >> "$log_file" 2>&1
    organic_exit=$?

    if [ $organic_exit -eq 0 ]; then
        ((success_organic++))
        organic_success_files+=("$input_file")
        echo "Exit code: 0 — OK" >> "$log_file"
        echo "  -> OK (organic mode)"
    else
        ((failed++))
        failed_files+=("$input_file")
        echo "Exit code: $organic_exit — FAILED" >> "$log_file"
        echo "  -> FAILED both modes (exit $organic_exit)"
    fi
done

{
    echo "========================================"
    echo "BATCH SUMMARY — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo "Total processed : $total"
    echo "Success CAD     : $success_cad"
    echo "Success organic : $success_organic"
    echo "Failed both     : $failed"
    echo "Skipped         : $skipped"
    echo ""
    echo "--- CAD SUCCESS (${#cad_success_files[@]}) ---"
    for f in "${cad_success_files[@]}"; do echo "  $f"; done
    echo ""
    echo "--- ORGANIC SUCCESS (${#organic_success_files[@]}) ---"
    for f in "${organic_success_files[@]}"; do echo "  $f"; done
    echo ""
    echo "--- FAILED (${#failed_files[@]}) ---"
    for f in "${failed_files[@]}"; do echo "  $f"; done
} | tee "$SUMMARY_FILE"

echo ""
echo "Logs   : $LOG_DIR"
echo "Summary: $SUMMARY_FILE"
