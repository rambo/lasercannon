/**
 * Standard right-angled triangle
 *
 * @param number o_len Lenght of the opposite side
 * @param number a_len Lenght of the adjacent side
 * @param number depth How wide/deep the triangle is in the 3rd dimension
 */
module triangle(o_len, a_len, depth)
{
	difference()
	{
		cube([depth, a_len, o_len], center=false);
		rotate([atan(o_len/a_len),0,0])
		{
			translate([-2.5,0,0])
			{
				cube([depth+5,sqrt(pow(a_len, 2) + pow(o_len,2))+2, o_len+2], center=false);
			}
		}
	}
}

/**
 * Align DS420 digital servo
 *
 * @param vector position The position vector
 * @param vector rotation The rotation vector
 * @param boolean screws If defined then "screws" will be added and when the module is differenced() from something if will have holes for the screws
 * @param number axle_lenght If defined this will draw "backgound" indicater for the main axle
 */
module alignds420(position, rotation, screws = 0, axle_lenght = 0)
{
	translate(position)
	{
		rotate(rotation)
	    {
			union()
			{
				// Main axle
				translate([0,0,17])
				{
					cylinder(r=6, h=8, $fn=30);
					cylinder(r=2.5, h=10.5, $fn=20);
				}
				// Box and ears
				translate([-6,-6,0])
				{
					cube([12, 22.8,19.5], false);
					translate([0,-5, 17]) 
					{
						cube([12, 7, 2.5]);
					}
					translate([0, 20.8, 17]) 
					{
						cube([12, 7, 2.5]);
					}
				}
				if (screws > 0)
				{
					translate([0,(-10.2 + 1.8),11.5])
					{
						# cylinder(r=1.8/2, h=6, $fn=6);
					}
					translate([0,(21.0 - 1.8),11.5])
					{
						# cylinder(r=1.8/2, h=6, $fn=6);
					}
					
				}
				// The large slope
				translate([6,18,19.0])
				{
					rotate([0,0,180])
					{
						triangle(4, 18, 12);
					}
				}

				/** 
				 * This seems to get too complex fast
				// Small additional axes
				translate([0,6,17])
				{
					cylinder(r=2.5, h=6, $fn=10);
					cylinder(r=1.25, h=8, $fn=10);
				}
				// Small slope
				difference()
				{
					translate([-6,-6,19.0])
					{
						cube([12,6.5,4]);
					}
					translate([-7,1,24.0])
					{
						rotate([180,0,0])
						{
							triangle(3, 8, 14);
						}
					}
				
				}
				*/
				// So we render a cube instead of the small slope on a cube
				translate([-6,-6,19.0])
				{
					cube([12,6.5,4]);
				}
			}
			if (axle_lenght > 0)
			{
				% cylinder(r=0.9, h=axle_lenght, center=true, $fn=8);
			}
		}
	}	
}

//alignds420(screws=1);

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

module kiikkulauta()
{
	assign (servo_height = 25, servo_x = 23, servo_y = 16.9, second_servo_y = 35, platform_width = 100)
	{
		assign(second_servo_height = servo_height-35)
		{
			// Alusta ja siihen servojen reiät+tuet
			difference()
			{
				union() 
				{
					alusta_c(35,platform_width,45);
					// 1. servon ruuviblokit
					translate([servo_x+6, servo_y-16, servo_height-6])
					{
						cube([5,7, 12]);
					}
					translate([servo_x-22, servo_y-16, servo_height-6])
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
			}
		}
	}
	
}

kiikkulauta();
