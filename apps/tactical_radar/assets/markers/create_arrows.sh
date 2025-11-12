#!/bin/bash

# Create simple triangle PNG files using ImageMagick (if available) or sf symbols
for size in 40 80 120; do
    suffix=""
    if [ $size -eq 80 ]; then suffix="@2x"; fi
    if [ $size -eq 120 ]; then suffix="@3x"; fi
    
    # Try using sips (built-in macOS tool) to create from text
    # We'll create a simple approach: use macOS screenshot utilities
    echo "Creating ${size}x${size} arrow assets..."
    
    # Create green arrow with transparent background
    cat > /tmp/arrow_green_${size}.svg << SVGEOF
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
  <rect width="$size" height="$size" fill="none"/>
  <g transform="translate($(($size/2)), $(($size/2)))">
    <polygon points="0,-$(($size/3)) -$(($size/4)),$(($size/3)) $(($size/4)),$(($size/3))"
             fill="lime" stroke="darkgreen" stroke-width="2"/>
  </g>
</svg>
SVGEOF

    # Create red arrow with transparent background
    cat > /tmp/arrow_red_${size}.svg << SVGEOF
<svg width="$size" height="$size" xmlns="http://www.w3.org/2000/svg">
  <rect width="$size" height="$size" fill="none"/>
  <g transform="translate($(($size/2)), $(($size/2)))">
    <polygon points="0,-$(($size/3)) -$(($size/4)),$(($size/3)) $(($size/4)),$(($size/3))"
             fill="red" stroke="darkred" stroke-width="2"/>
  </g>
</svg>
SVGEOF

    # Convert SVG to PNG with transparency
    # Try multiple conversion methods
    if command -v rsvg-convert &> /dev/null; then
        echo "Using rsvg-convert..."
        rsvg-convert -w $size -h $size -b none /tmp/arrow_green_${size}.svg > "arrow_green${suffix}.png"
        rsvg-convert -w $size -h $size -b none /tmp/arrow_red_${size}.svg > "arrow_red${suffix}.png"
    elif command -v convert &> /dev/null; then
        echo "Using ImageMagick convert..."
        convert -background none -size ${size}x${size} /tmp/arrow_green_${size}.svg "arrow_green${suffix}.png"
        convert -background none -size ${size}x${size} /tmp/arrow_red_${size}.svg "arrow_red${suffix}.png"
    else
        echo "Neither rsvg-convert nor ImageMagick found."
        echo "Please install with: brew install librsvg imagemagick"
        echo "Or manually convert SVGs in /tmp/ to PNG with transparent background"
        exit 1
    fi
done

echo "PNG files created with transparent backgrounds!"
echo "Files: arrow_green.png, arrow_green@2x.png, arrow_green@3x.png"
echo "       arrow_red.png, arrow_red@2x.png, arrow_red@3x.png"
