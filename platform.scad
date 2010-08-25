use </Users/rambo/devel/MCAD/servos.scad>


module alusta_c(size_x, size_y, size_z)
{
	difference()
	{
		cube([size_x,size_y,size_z]);
		translate([-5,2,2])
		{
			cube([size_x+10, size_y-4, size_z]);
		}
	}
}


module laser(heatsink = 0, x_axle = 110)
{
    union()
    {
        cylinder(r=6, h= 20, $fn=30);
        cylinder(r=4, h= 30, $fn=30);
        translate([0,0,-5])
        {
            cube([11.8,2,15], center=true);
        }
        
        
        if (heatsink > 0)
        {
            translate([0,0,2])
            {
                cylinder(r=10, h=18, $fn=30);
            }
        }
        if (x_axle > 1)
        {
            translate([0,0,25])
            {
                rotate([0,90,0])
                {
                    % cylinder(r=0.5, h=x_axle, $fn=6, center=true);
                }
            }
        }
    }
}

//laser();

/** 
 * seeduino slotti
 * millin syvennykset/sisennykset (miten ne urat nyt haluaa ajatella) mahtuu reinoille
 * leveys 53.3mm (eagle)
 * syvyys 94mm (eagle)
 * paksuus 1mm ?
 */

module kiikkulauta()
{
	assign (servo_height = 25, servo_x = 29, servo_y = 16.9, second_servo_y = 35, platform_width = 100)
	{
		assign(second_servo_height = servo_height-35)
		{
			// Alusta ja siihen servojen reiät+tuet
			difference()
			{
				union() 
				{
					alusta_c(40,platform_width,45);
					// 1. servon ruuviblokit
					translate([servo_x+6, servo_y-16, servo_height-6])
					{
						cube([5,7, 12]);
					}
					translate([servo_x-21.8, servo_y-16, servo_height-6])
					{
						cube([5,7, 12]);
					}
					// 2. servon tuet/ruuviblokit
					translate([servo_x-6,second_servo_y-10.9, 0.5])
					{
						cube([12,4.9, second_servo_height+16.4]);
					}
					translate([servo_x-6,second_servo_y+16.8, 0.5])
					{
						cube([12,4.9, second_servo_height+16.4]);
					}
					// Alustan tukiakseli
					translate([servo_x, platform_width+5, servo_height])
					{
						rotate([90,0,0])
						{
							 cylinder(r=1, h=6, $fn=16);
						}
					}
				}
				# alignds420([servo_x,servo_y,servo_height], [90,-90,0],1, 200);
				# alignds420([servo_x+0.25,second_servo_y,second_servo_height], [0,0,0],1);
                translate([10,35,0])
                {
                   # laser(1);
                }
			}
		}
	}
	
}

 kiikkulauta();
