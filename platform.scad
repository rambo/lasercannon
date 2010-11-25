/**
 * TODO: Switch all comments to english
 *
 * NOTE: This is a very preliminary design, and might not work so don't
 * copy it and expect it to be any good.
 */

use </Users/rambo/devel/MCAD/servos.scad>
use </Users/rambo/devel/MCAD/triangles.scad>


/**
 * Laakeri: ulko halk 22mm sisähalk 8mm
 */

/*
module alusta_c(size_x, size_y, size_z)
{
    difference()
    {
        cube([size_x,size_y,size_z]);
        translate([-5,5,5])
        {
            cube([size_x+10, size_y-10, size_z]);
        }
    }
}
// alusta_c(45,120,45);

*/

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
                translate([slot_width*i*2+slot_width, thickness, thickness-1])
                {
                    cube([slot_width, thickness+0.5, thickness/2+1]);
                }
            }
        }
        # alignds420([servo_x_posx,servo_y_height,16.9], [0,180,90], 1);
        for (i = [0 : slots-1])
        {
            translate([slot_width*i*2, -0.5, -0.5])
            {
                 cube([slot_width, thickness+0.5, thickness+1]);
            }
        }
    }
}

// servo_wall();

module baseplate(platform_x=45, platform_y=120, thickness= 5, servo_x_posx=34, servo_x_posy=50, servo_y_height=30, slots=5)
{
    // No not add semicolons to these assigns (context)
    assign(slot_width = platform_x/2/slots)
    assign(servo_x_height=servo_y_height-35)
    assign(servo_support_z=13+servo_x_height)
    difference()
    {
        union()
        {
            cube([platform_x,platform_y,thickness]);
            translate([servo_x_posx-5.5, servo_x_posy+16.7, thickness-1])
            {
                cube([11,5,servo_support_z]);
            }
            translate([servo_x_posx-5.5, servo_x_posy-10.7, thickness-1])
            {
                cube([11,5,servo_support_z]);
            }
            for (i = [0 : slots-1])
            {
                translate([slot_width*i*2+slot_width, platform_y-thickness*2, thickness-1])
                {
                    cube([slot_width-0.1, thickness, thickness/2+1]);
                }
                translate([slot_width*i*2, thickness-0.1, thickness-1])
                {
                    cube([slot_width, thickness+0.5, thickness/2+1]);
                }
            }
        }
        # alignds420([servo_x_posx,servo_x_posy,servo_x_height], [0,0,0], 1);
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
    }
}

baseplate();

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
 * seeduino slotti
 * millin syvennykset/sisennykset (miten ne urat nyt haluaa ajatella) mahtuu reinoille
 * leveys 54mm
 * syvyys 69mm 
 * paksuus 1.5mm
 */
/*
module kiikkulauta()
{
    assign (servo_height = 30, servo_x = 34, servo_y = 16.9, second_servo_y = 40, platform_width = 120, mirror1_angle = 70)
    {
        assign(second_servo_height = servo_height-35)
        {
            // Alusta ja siihen servojen reiät+tuet
            difference()
            {
                union() 
                {
                    alusta_c(45,platform_width,45);
                    // 1. servon ruuviblokit
                    translate([servo_x+6, servo_y-16, servo_height-6])
                    {
                        cube([5,7, 12]);
                        // overhang-support
                        rotate([0,90,0])
                        {
                           triangle(7,7,5);
                        }
                    }
                    translate([servo_x-21.8, servo_y-16, servo_height-6])
                    {
                        cube([5,7, 12]);
                        // overhang-support
                        rotate([0,90,0])
                        {
                            triangle(7,7,5);
                        }
                    }
                    // 2. servon tuet/ruuviblokit
                    translate([servo_x-5.75,second_servo_y-10.9, 0.5])
                    {
                        cube([12,4.9, second_servo_height+16.4]);
                    }
                    translate([servo_x-5.75,second_servo_y+16.8, 0.5])
                    {
                        cube([12,4.9, second_servo_height+16.4]);
                    }
                    // Alustan tukiakseli/laakeri
                    translate([servo_x, platform_width+5, servo_height])
                    {
                        rotate([90,0,0])
                        {
                             cylinder(r=1, h=6, $fn=16);
                        }
                    }
                    // Laserin pidike
                    translate([0,25+second_servo_y,1])
                    {
                        cube([25,15,15]);
                    }
                    // Laserin peilipidike
                    translate([8,+second_servo_y,4])
                    {
                        rotate([90,0,45])
                        {
                            a_triangle(mirror1_angle, 7, 7);
                        }
                    }
                    // Säteen heijastus
                    translate([13,second_servo_y,14])
                    {
                        rotate([0,-90+2*mirror1_angle,0])
                        {
                            % cylinder(r=0.5, h=40, $fn=6, center=false);
                        }
                    }
                }
                # alignds420([servo_x,servo_y,servo_height], [90,-90,0],1, 200);
                # alignds420([servo_x+0.25,second_servo_y,second_servo_height], [0,0,0],1);
                translate([13.5,50+second_servo_y,14])
                {
                    rotate([90,0,0])
                    {
                        # laser(1);
                    }
                }
            }
        }
    }
    
}

kiikkulauta();
*/



