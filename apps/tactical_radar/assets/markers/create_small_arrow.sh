#!/bin/bash
# Create tiny green arrow for ownship (15px)

cat > /tmp/arrow_green_tiny.svg << SVGEOF
<svg width="15" height="15" xmlns="http://www.w3.org/2000/svg">
  <rect width="15" height="15" fill="none"/>
  <g transform="translate(7.5, 7.5)">
    <polygon points="0,-6 -4,6 4,6"
             fill="lime" stroke="darkgreen" stroke-width="1"/>
  </g>
</svg>
SVGEOF

rsvg-convert -w 15 -h 15 -b none /tmp/arrow_green_tiny.svg > arrow_green_tiny.png

echo "Created arrow_green_tiny.png (15x15px)"
ls -lh arrow_green_tiny.png
