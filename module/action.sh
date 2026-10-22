#!/system/bin/sh
echo 'Leica 0.266 native configuration split'
cat /data/adb/leica-stock-sr-266/status 2>/dev/null
echo 'Selected profile / camera core / original JSON SHA256:'
cat /data/adb/leica-stock-sr-266/selection.txt 2>/dev/null
echo 'ready means configuration checks passed; confirm ordinary and Leica photos.'
