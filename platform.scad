/**
 * TODO: Switch all comments to english
 *
 * NOTE: This is a very preliminary design, and might not work so caveat emptor
 */

use </Users/rambo/devel/MCAD/servos.scad>
use </Users/rambo/devel/MCAD/triangles.scad>



/**
 * Servo-wall piece of the platform, meant to be printed on it's side
 */
module servo_wall(platform_x=45, servo_y_height=30, servo_x_posx=34, thickness=5, slots = 4)
{
    // No not add semicolons to these assigns (context)
    assign(slot_width = platform_x/2/slots) 
    assign(wall_height = servo_y_height+15)
    difference()
    {
        union()
        {
            cube([platform_x,wall_height,thickness]);
            translate([servo_x_posx+5.3, servo_y_height-5.5, thickness-1])
            {
                cube([5,11,10-thickness]);
            }
            translate([servo_x_posx-21, servo_y_height-5.5, thickness-1])
            {
                cube([5,11,10-thickness]);
            }
            for (i = [0 : slots-1])
            {
                translate([slot_width*i*2, thickness, thickness-1])
                {
                    cube([slot_width, thickness/2, thickness/2+1]);
                }
            }
        }
        # alignds420([servo_x_posx,servo_y_height,16.9], [0,180,90], 1, 150);
        for (i = [0 : slots-1])
        {
            translate([slot_width*i*2+slot_width, -0.5, -0.5])
            {
                 cube([slot_width+0.1, thickness+0.5, thickness+1]);
            }
        }
    }
}

// servo_wall();

/**
 * Baseplate with the X servo & laser
 *
 * @todo: place laser
 * @todo: place mirror
 */
module baseplate(platform_x=45, platform_y=130, thickness=5, servo_x_posx=34, servo_x_posy=50, servo_y_height=30, slots=5)
{
    // No not add semicolons to these assigns (context)
    assign(slot_width = platform_x/2/slots)
    assign(servo_x_height=servo_y_height-35)
    assign(servo_support_z=13+servo_x_height)
    assign(laser_x=13.5, laser_y=50+servo_x_posy, laser_z=10+thickness-1)
    // TODO: Calculate based on servo_y_height
    assign(mirror1_angle=70)
    difference()
    {
        union()
        {
            // Base
            cube([platform_x,platform_y,thickness]);

            // servo_x supports
            translate([servo_x_posx-5.5, servo_x_posy+16.7, thickness-1])
            {
                cube([11,5,servo_support_z]);
            }
            translate([servo_x_posx-5.5, servo_x_posy-10.7, thickness-1])
            {
                cube([11,5,servo_support_z]);
            }

            // Laser support
            translate([laser_x-(10+3.5),laser_y-20, 0])
            {
                cube([20+2*3.5,10,laser_z+5]);
            }

            // Laser mirror holder
            // TODO: Calculate the magic number (8) from known variables
            translate([8,servo_x_posy,thickness-1])
            {
                rotate([90,0,45])
                {
                    // TODO: Where do the magic numbers (7,7) come from ?
                    a_triangle(mirror1_angle, 7, 7);
                }
            }
            // laser reflection helper
            // TODO: Calculate the magic numbers (13,14) from known variables
            translate([13,servo_x_posy,14])
            {
                rotate([0,-90+2*mirror1_angle,0])
                {
                    % cylinder(r=0.5, h=40, $fn=6, center=false);
                }
            }

            // joining slots
            for (i = [0 : slots-1])
            {
                translate([slot_width*i*2+slot_width, platform_y-thickness*1.5, thickness-1])
                {
                    cube([slot_width-0.1, thickness/2, thickness/2+1]);
                }
                // These need to be taller since the wall module has no support tabs 
                translate([slot_width*i*2, thickness-0.1, thickness-1])
                {
                    cube([slot_width, thickness+0.5, thickness+1]);
                }
            }
        }
        # alignds420([servo_x_posx,servo_x_posy,servo_x_height], [0,0,0], 1, 150);
        // joining slots
        for (i = [0 : slots-1])
        {
            translate([slot_width*i*2-0.1, platform_y-thickness, -0.5])
            {
                 cube([slot_width+0.1, thickness+0.5, thickness+1]);
            }
            translate([slot_width*i*2+slot_width, -0.5, -0.5])
            {
                 cube([slot_width+0.1, thickness+0.5, thickness+1]);
            }
        }
        translate([laser_x,laser_y, laser_z])
        {
            rotate([90,0,0])
            {
                # laser(1);
            }
        }
    }
}

// baseplate();


/**
 * Module to assemble the parts for the seesaw Y-platform
 */
module y_platform(platform_x=45, platform_y=130, thickness=5, servo_x_posx=34, servo_x_posy=50, servo_y_height=30, slots=5)
{
    // Assign properties by name just in case
    baseplate(platform_x, platform_y, thickness, servo_x_posx, servo_x_posy, servo_y_height, slots);
    translate([0,platform_y,0])
    {
        rotate([90,0,0])
        {
            servo_wall(platform_x, servo_y_height, servo_x_posx, thickness, slots);
        }
    }
    translate([0,thickness,0])
    {
        rotate([90,0,0])
        {
            bearing_wall(platform_x, servo_y_height, servo_x_posx, thickness, slots);
        }
    }
}

 y_platform();

/**
 * Bearing-wall piece of the platform, meant to be printed on it's side
 */
module bearing_wall(platform_x=45, servo_y_height=30, servo_x_posx=34, thickness=5, slots = 4)
{
    // No not add semicolons to these assigns (context)
    assign(slot_width = platform_x/2/slots) 
    assign(wall_height = servo_y_height+15)
    difference()
    {
        union()
        {
            cube([platform_x,wall_height,thickness]);
            // Additional supports for the bearing
            translate([servo_x_posx,servo_y_height,0])
            {
                cylinder(r=13, h=7, $fn=30);
            }
            
            /**
             * The end up on the wrong side when the wall is lifted to position
            for (i = [0 : slots-1])
            {
                translate([slot_width*i*2+slot_width-0.1, thickness, thickness-1])
                {
                    cube([slot_width, thickness+0.5, thickness/2+1]);
                }
            }
             */
        }
        // Bearing holes
        translate([servo_x_posx,servo_y_height,0])
        {
            translate([0,0,2])
            {
                // The skateboard bearing (outer r=11mm inner r=4mm z=7mm)
                cylinder(r=11, h=7, $fn=30);
            }
            translate([0,0,-2])
            {
                // Drill hole
                cylinder(r=4, h=12, $fn=30);
            }
        }
        for (i = [0 : slots-1])
        {
            translate([slot_width*i*2-0.1, -0.5, -0.5])
            {
                 cube([slot_width+0.1, thickness+0.5, thickness+1]);
            }
        }
    }
}

// bearing_wall();

/**
 * DX green laser module (plus my own 20mm heatsink)
 */
module laser(heatsink = 0, x_axle = 110)
{
    union()
    {
        cylinder(r=6, h= 28, $fn=30);
        cylinder(r=4, h= 39, $fn=30);
        translate([-5,-2,-19])
        {
            cube([10,4,20], false);
        }
        
        
        if (heatsink > 0)
        {
            translate([0,0,2])
            {
                cylinder(r=10, h=26, $fn=30);
            }
        }
        if (x_axle > 1)
        {
            /*
            translate([0,0,35])
            {
                rotate([0,90,0])
                {
                    % cylinder(r=0.5, h=x_axle, $fn=6, center=true);
                }
            }
            */
            % cylinder(r=0.5, h=x_axle, $fn=6, center=true);
        }
    }
}

// laser();

/** 
 * Old notes, but I might still need them later (dimensions for the Seeeduino board)
 *
 * seeduino slotti
 * millin syvennykset/sisennykset (miten ne urat nyt haluaa ajatella) mahtuu reinoille
 * leveys 54mm (width)
 * syvyys 69mm  (lenght)
 * paksuus 1.5mm (thickness [the PCB, not counting components...])
 */

