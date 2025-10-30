#!/bin/bash

# Create simple triangle PNG files using ImageMagick (if available) or sf symbols
for size in 40 80 120; do
    suffix=""
    if [ $size -eq 80 ]; then suffix="@2x"; fi
    if [ $size -eq 120 ]; then suffix="@3x"; fi
    
    # Try using sips (built-in macOS tool) to create from text
    # We'll create a simple approach: use macOS screenshot utilities
    echo "Creating ${size}x${size} arrow assets..."
    
    # Create green arrow
    cat > /tmp/arrow_green_${size}.svg << SVGEOF
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate($(($size/2)), $(($size/2)))">
    <polygon points="0,-$(($size/3)) -$(($size/4)),$(($size/3)) $(($size/4)),$(($size/3))" 
             fill="lime" stroke="white" stroke-width="2"/>
  </g>
</svg>
SVGEOF

    # Create red arrow
    cat > /tmp/arrow_red_${size}.svg << SVGEOF
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
  <g transform="translate($(($size/2)), $(($size/2)))">
    <polygon points="0,-$(($size/3)) -$(($size/4)),$(($size/3)) $(($size/4)),$(($size/3))" 
             fill="red" stroke="white" stroke-width="2"/>
  </g>
</svg>
SVGEOF

done

echo "SVG files created in /tmp/"
echo "Please convert them to PNG using: qlmanage -t -s SIZE -o . /tmp/arrow_green_SIZE.svg"
