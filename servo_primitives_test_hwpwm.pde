// Load the servoshield library in high-accuracy mode
#include <math.h> 
#include <SimpleFIFO.h> 
#include <avr/interrupt.h> 


//Servo control via direct access to AVR PWM registers

#define SERVO_CHANNELS 2
#define LASER_CHANNELS 1
#define D_OUT_PIN_MIN 2
#define D_OUT_PIN_MAX 5

// Microseconds it takes for servo to travel one from (pulse width) uSec to uSec+1
byte servo_delays[SERVO_CHANNELS] = 
{
    150,
    150,
};

//servo constants -- trim as needed http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1222623026/2
// Most servos are analog devices so the exact null point may vary somewhat device to device.
// This is particularly true of continuous rotation servos.
int servo_trim[SERVO_CHANNELS] =
{
    1500,
    1500,
};

volatile unsigned int servo_ports[SERVO_CHANNELS] =
{
    OCR1A,
    OCR1B,
};

volatile int last_servo_value[SERVO_CHANNELS];


boolean servo_reverse[SERVO_CHANNELS] =
{
   true,
   true,
};

// NOTE: The FIFO will work a lot better if this is fits to single byte
#define QUEUE_STACK_SIZE 128

SimpleFIFO<int,QUEUE_STACK_SIZE> servo_queue[SERVO_CHANNELS];

// Store expected micros() timestamp for servo to be done with it's current movement
unsigned long servo_ready[SERVO_CHANNELS]; 


// Command queue
#define COMMAND_STRING_SIZE 18 //Remember to allocate for the null termination
#define COMMAND_QUEUE_SIZE 25 // NOTE: Raising this will *easily* make the board run out of SRAM

char command_queue[COMMAND_QUEUE_SIZE][COMMAND_STRING_SIZE];
//char command_queue[COMMAND_QUEUE_SIZE][COMMAND_STRING_SIZE];
byte command_queue_position;
byte command_queue_end;
char incoming_command[COMMAND_STRING_SIZE+2]; //Reserve space for CRLF too.
byte incoming_position;

// Interrupt handler for emptying the servo command queue.
#define TIMER_CLOCK_FREQ 15616.0 // 16Mhz / 1024 prescaler
byte timer2_offset;
//Timer2 overflow interrupt vector handler
ISR(TIMER2_OVF_vect)
{
    // Toggle pin 7 to count frequency (true freq for ISV if freq seen in oscilloscope * 2)
    //digitalWrite(7,!digitalRead(7));

    check_servo_queue();

    // Reset timer to offset
    TCNT2 = timer2_offset;
}

void setup()
{
    Serial.begin(57600);

    // Direct HW-PWM servo control (http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1222623026/2)
    pinMode(9,OUTPUT);
    pinMode(10,OUTPUT);
    TCCR1B = 0b00011010;	    // Fast PWM, top in ICR1, /8 prescale (.5 uSec)
    TCCR1A = 0b10100010;	    //clear on compare match, fast PWM
  					  // to use pin 9 as normal input or output, use  TCCR1A = 0b00100010
  					  // to use pin 10 as normal input or output, use  TCCR1A = 0b10000010
//    ICR1 =  39999;		    // 40,000 clocks @ .5 uS = 20mS
    ICR1 =  20000;		    // 100Hz PWM refresh rate
    // direct init the port for now
    /*
    OCR1A = servo_trim[0];
    OCR1B = servo_trim[1];
    */

    unsigned long time = micros();
    for (byte channel = 0; channel < SERVO_CHANNELS; channel++) //Initialize all servos 
    {
        servo_ready[channel] = time;
        queue_servo_position(channel, 500);
    }

    // Pins 2-5 for digital out
    for (byte pin = D_OUT_PIN_MIN; pin <= D_OUT_PIN_MAX; pin++)
    {
        pinMode(pin, OUTPUT);
        digitalWrite(pin, HIGH);
    }

    timer2_offset = (int)((257.0-(TIMER_CLOCK_FREQ / 150))+0.5); //offset timer for 150Hz
    Serial.print("timer2_offset ");
    Serial.println(timer2_offset, DEC);

    //Timer2 Settings: Timer Prescaler /1024, WGM mode 0
    TCCR2A = 0;
    TCCR2B = _BV(CS22) | _BV(CS21) | _BV(CS20);

    Serial.print("TCCR2B set to: ");
    Serial.println(TCCR2B, BIN);

    //Timer2 Overflow Interrupt Enable  
    TIMSK2 = 1<<TOIE2;
    //reset timer to offset
    TCNT2 = timer2_offset;


    Serial.println("Board booted");
    delay(5000);
    
}

inline void read_command_bytes()
{
    for (byte d = Serial.available(); d > 0; d--)
    {
        incoming_command[incoming_position] = Serial.read();

        Serial.print("DEBUG: Got byte: ");
        Serial.println(incoming_command[incoming_position]);

        // Check for line end and in such case do special things
        if (   incoming_command[incoming_position] == 0xA // LF
            || incoming_command[incoming_position] == 0xD) // CR
        {
            incoming_command[incoming_position] = 0x0;
            if (   incoming_position > 0
                && (   incoming_command[incoming_position-1] == 0xD // CR
                    || incoming_command[incoming_position-1] == 0xA) // LF
               )
            {
                incoming_command[incoming_position-1] = 0x0;
            }
            // Using strncpy to copy the incoming command to command queue
            //strncpy(command_queue[command_queue_end], incoming_command, COMMAND_STRING_SIZE);
            memcpy(command_queue[command_queue_end], incoming_command, COMMAND_STRING_SIZE);

            Serial.print("DEBUG: Got command: '");
            for (byte i=0; i <= COMMAND_STRING_SIZE; i++)
            {
                Serial.print(command_queue[command_queue_end][i]);
            }
            Serial.println("'");

            // Using memset to clear the incoming command
            memset(&incoming_command, 0, COMMAND_STRING_SIZE+2);
            
            command_queue_end++;
            if (command_queue_end == COMMAND_QUEUE_SIZE)
            {
                Serial.println("NOTICE: Command buffer full");
                for (byte i=0; i <= COMMAND_QUEUE_SIZE; i++)
                {
                    Serial.print("DEBUG: command_buffer[");
                    Serial.print(i, DEC);
                    Serial.print("]: ");
                    for (byte i2=0; i2 <= COMMAND_STRING_SIZE; i2++)
                    {
                        Serial.print(command_queue[i][i2]);
                    }
                    Serial.println("");
                }
                Serial.println("NOTICE: Next command will overwrite last one");
                command_queue_end--;
            }
            incoming_position = 0;
            return;
        }
        incoming_position++;

        // Sanity check buffer sizes
        if (incoming_position > COMMAND_STRING_SIZE+2)
        {
            Serial.print("PANIC: No end-of-line seen and incoming_position=");
            Serial.print(incoming_position, DEC);
            Serial.println(" clearing buffers");
            
            memset(&incoming_command, 0, COMMAND_STRING_SIZE+2);
            incoming_position = 0;
        }
    }
}


inline void process_commands()
{
    for (byte i=0; i <= command_queue_end; i++)
    {
        parse_command(i);
    }
}

inline int bytes2int(byte i1, byte i2)
{
    /*
    Serial.print("bytes2int: i1=");
    Serial.print(i1, BIN);
    Serial.print(" i2=");
    Serial.print(i2, BIN);
    */
    int tmp = i1;
    tmp <<= 8;
    tmp += i2;
    /*
    Serial.print(" returning: ");
    Serial.print(tmp, DEC);
    Serial.print(" (");
    Serial.print(tmp, BIN);
    Serial.println(")");
    */
    return tmp;
}

inline void parse_command(byte key)
{
    switch (command_queue[key][0])
    {
        case 0x0:
            return;
            break;
        // void laser(byte channel, boolean state)
        case 0x41: // ASCII "A"
            laser(command_queue[key][1], command_queue[key][2]);
            break;
        // void vector(byte start_channel, int angle, int power, int origo_x, int origo_y)
        case 0x42: // ASCII "B"
        // see http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1212158155/2
        {
            int angle = bytes2int(command_queue[key][2], command_queue[key][3]);
            int power = bytes2int(command_queue[key][4], command_queue[key][5]);
            int origo_x = bytes2int(command_queue[key][6], command_queue[key][7]);
            int origo_y = bytes2int(command_queue[key][8], command_queue[key][9]);
            vector(command_queue[key][1], angle, power, origo_x, origo_y);
        }
            break;
        // void line(byte start_channel, int start_x, int start_y, int end_x, int end_y)
        case 0x43: // ASCII "C"
        {
            int start_x = bytes2int(command_queue[key][2], command_queue[key][3]);
            int start_y = bytes2int(command_queue[key][4], command_queue[key][5]);
            int end_x = bytes2int(command_queue[key][6], command_queue[key][7]);
            int end_y = bytes2int(command_queue[key][8], command_queue[key][9]);
            line(command_queue[key][1], start_x, start_y, end_x, end_y);
        }
            break;
        // void circle(byte start_channel, int radius, int origo_x, int origo_y, byte range_step)
        case 0x44: // ASCII "D"
        {
            //Serial.println("DEBUG pase_command: E matched");
            int radius = bytes2int(command_queue[key][2], command_queue[key][3]);
            int origo_x = bytes2int(command_queue[key][4], command_queue[key][5]);
            int origo_y = bytes2int(command_queue[key][6], command_queue[key][7]);

            /*
            Serial.print("DEBUG Calling: circle(");
            Serial.print(command_queue[key][1], DEC);
            Serial.print(", ");
            Serial.print(radius, DEC);
            Serial.print(", ");
            Serial.print(origo_x, DEC);
            Serial.print(", ");
            Serial.print(origo_y, DEC);
            Serial.print(", ");
            Serial.print(command_queue[key][8], DEC);
            Serial.println(") ");
            */

            circle(command_queue[key][1], radius, origo_x, origo_y, command_queue[key][8]);
        }
            break;
        // void span(byte start_channel, int radius, int origo_x, int origo_y, byte range_step, int range_start, int range_end)
        case 0x45: // ASCII "E"
        {
            //Serial.println("DEBUG pase_command: F matched");
            int radius = bytes2int(command_queue[key][2], command_queue[key][3]);
            int origo_x = bytes2int(command_queue[key][4], command_queue[key][5]);
            int origo_y = bytes2int(command_queue[key][6], command_queue[key][7]);
            int range_start = bytes2int(command_queue[key][9], command_queue[key][10]);
            int range_end = bytes2int(command_queue[key][11], command_queue[key][12]);
            /*
            Serial.print("DEBUG Calling: span(");
            Serial.print(command_queue[key][1], DEC);
            Serial.print(", ");
            Serial.print(radius, DEC);
            Serial.print(", ");
            Serial.print(origo_x, DEC);
            Serial.print(", ");
            Serial.print(origo_y, DEC);
            Serial.print(", ");
            Serial.print(command_queue[key][8], DEC);
            Serial.print(", ");
            Serial.print(range_start, DEC);
            Serial.print(", ");
            Serial.print(range_end, DEC);
            Serial.println(") ");
            */
            span(command_queue[key][1], radius, origo_x, origo_y, command_queue[key][8], range_start, range_end);
        }
          break;
        case 0x46: // ASCII "F", laser state and xy
        {
            Serial.print("DEBUG Calling: laser(");
            Serial.print(command_queue[key][1], DEC);
            Serial.print(", ");
            Serial.print(command_queue[key][2], DEC);
            Serial.println(") ");
            laser(command_queue[key][1], command_queue[key][2]);
            int x = bytes2int(command_queue[key][4], command_queue[key][5]);
            int y = bytes2int(command_queue[key][6], command_queue[key][7]);
            Serial.print("DEBUG Calling: queue_servo_position(");
            Serial.print(command_queue[key][3], DEC);
            Serial.print(", ");
            Serial.print(x, DEC);
            Serial.println(") ");
            queue_servo_position(command_queue[key][3], x);
            Serial.print("DEBUG Calling: queue_servo_position(");
            Serial.print(command_queue[key][3]+1, DEC);
            Serial.print(", ");
            Serial.print(y, DEC);
            Serial.println(") ");
            queue_servo_position(command_queue[key][3]+1, y);
        }
          break;
        // Print command queue
        case 0x77: // ASCII "w"
            for (byte i=0; i <= command_queue_end; i++)
            {
                Serial.print("INFO: command_buffer[");
                Serial.print(i, DEC);
                Serial.print("]: ");
                for (byte i2=0; i2 <= COMMAND_STRING_SIZE; i2++)
                {
                    Serial.print(command_queue[i][i2]);
                }
                Serial.println("");
            }
            command_queue[key][0] = 0x0;
            break;
        // Wait for servo X
        case 0x78: // ASCII "x"
            wait_for_servo(command_queue[key][1]);
            break;
        // Wait for all servos
        case 0x79: // ASCII "y"
            for (byte channel = 0; channel < SERVO_CHANNELS; channel++)
            {
                wait_for_servo(channel);
            }
            break;
        // reset queue
        case 0x7A: // ASCII "z"
            if (command_queue[key][1] == 0x7A)
            {
                reset_command_queue();
            }
            break;
        default:
          Serial.print("ERROR pase_command: command not recognized, command_queue[key][0]=");
          Serial.println(command_queue[key][0]);
    }
}

void reset_command_queue()
{
    // reset the queue
    for (byte i=0; i <= COMMAND_QUEUE_SIZE; i++)
    {
        memset(&command_queue[i], 0, COMMAND_STRING_SIZE);
    }
    command_queue_end = 0;
    Serial.println("INFO: Command queue reset");
}

unsigned int loop_i;
void loop()
{
    loop_i++;
    read_command_bytes();
    process_commands();
    for (byte channel = 0; channel < SERVO_CHANNELS; channel++)
    {
        check_servo_queue();
        /*
        Serial.print("DEBUG: loop #");
        Serial.print(loop_i, DEC);
        Serial.print(" waiting for servo ");
        Serial.print(channel, DEC);
        Serial.print(" that has ");
        Serial.print(servo_queue[channel].count(), DEC);
        Serial.println(" commands in queue");
        */
        wait_for_servo(channel);
    }
}

void laser(byte channel, boolean state)
{
    // TODO: make sure the pin is in range
    digitalWrite(D_OUT_PIN_MIN + channel, state);
}

void vector(byte start_channel, int angle, int power, int origo_x, int origo_y)
{
    float rad = deg2rad(angle);
    int x = int(round(cos(rad) * power + origo_x));
    int y = int(round(sin(rad) * power + origo_y));
    line(start_channel, origo_x, origo_y, x, y);
}

void line(byte start_channel, int start_x, int start_y, int end_x, int end_y)
{
    /*
    Serial.print("line: start_x=");
    Serial.print(start_x, DEC);
    Serial.print(" start_y=");
    Serial.println(start_y, DEC);
    Serial.print("line: end_x=");
    Serial.print(end_x, DEC);
    Serial.print(" end_y=");
    Serial.println(end_y, DEC);
    */

    byte end_channel = start_channel + 1;
    // Set servo to initial position with laser off.
    laser(0, LOW);
    queue_servo_position(start_channel, start_x);
    queue_servo_position(end_channel, start_y);
    wait_for_servo(start_channel);
    wait_for_servo(end_channel);
    laser(0, HIGH);
    queue_servo_position(start_channel, end_x);
    queue_servo_position(end_channel, end_y);
}

/**
 * circle is a special case of span (going from 0 to 360 deg)
 */
inline void circle(byte start_channel, int radius, int origo_x, int origo_y, byte range_step)
{
    /*
    Serial.print("circle: origo_x=");
    Serial.print(origo_x, DEC);
    Serial.print(" origo_y=");
    Serial.println(origo_y, DEC);
    Serial.print("circle: radius=");
    Serial.print(" range_step=");
    Serial.println(range_step, DEC);
    */
    span(start_channel, radius, origo_x, origo_y, range_step, 0, 360);
}

void span(byte start_channel, int radius, int origo_x, int origo_y, byte range_step, int range_start, int range_end)
{
    /*
    Serial.print("span: origo_x=");
    Serial.print(origo_x, DEC);
    Serial.print(" origo_y=");
    Serial.println(origo_y, DEC);
    Serial.print("span: radius=");
    Serial.print(radius, DEC);
    Serial.print(" range_start=");
    Serial.print(range_start, DEC);
    Serial.print(" range_end=");
    Serial.print(range_end, DEC);
    Serial.print(" range_step=");
    Serial.println(range_step, DEC);
    */

    byte end_channel = start_channel + 1;
    // Send servo commands only if position changed, for that goal store last calculated x&y
    int last_x;
    int last_y;

    // Set servo to initial position with laser off.
    wait_for_servo(start_channel);
    wait_for_servo(end_channel);
    laser(0, LOW);
    float rad = deg2rad(range_start);
    int x = int(round(cos(rad) * radius + origo_x));
    int y = int(round(sin(rad) * radius + origo_y));
    queue_servo_position(start_channel, x);
    queue_servo_position(end_channel, y);
    wait_for_servo(start_channel);
    wait_for_servo(end_channel);
    laser(0, HIGH);

    byte i = 0;
    for (float angle = range_start; angle <= range_end; angle += range_step)
    {
        angle = constrain(angle, range_start, range_end);
        float rad = deg2rad(angle);

        int x = int(round(cos(rad) * radius + origo_x));
        int y = int(round(sin(rad) * radius + origo_y));

        /*
        Serial.print("angle=");
        Serial.print(angle, DEC);
        Serial.print(" x=");
        Serial.print(x, DEC);
        Serial.print(" y=");
        Serial.println(y, DEC);
        */

        if (x != last_x)
        {
            i++;
            queue_servo_position(start_channel, x);
        }
        if (y != last_y)
        {
            i++;
            queue_servo_position(end_channel, y);
        }


        // If we fill the queue wait for slots to free, this is kinda slow but I can't think of better way for now
        if (servo_queue[start_channel].count() == QUEUE_STACK_SIZE)
        {
            delayMicroseconds(servo_delays[start_channel]);
        }
        if (servo_queue[end_channel].count() == QUEUE_STACK_SIZE)
        {
            delayMicroseconds(servo_delays[end_channel]);
        }
    }
}

boolean queue_servo_position(byte channel, int position)
{
    if (channel >= SERVO_CHANNELS)
    {
        // channels start from 0 thus >=
        return false;
    }
    return servo_queue[channel].enqueue(position);
    /*
    boolean ret = servo_queue[channel].enqueue(position);
    Serial.print("queue_servo_position: channel ");
    Serial.print(channel, DEC);
    Serial.print(" (position: ");
    Serial.print(position, DEC);
    Serial.print(") ");
    Serial.print(" has ");
    Serial.print(servo_queue[channel].count(), DEC);
    Serial.println(" items in queue");
    return ret;
    */
}

void wait_for_servo(byte channel)
{
    /*
    Serial.print("wait_for_servo: channel ");
    Serial.print(channel, DEC);
    Serial.print(" has ");
    Serial.print(servo_queue[channel].count(), DEC);
    Serial.println(" items in queue");
    */
    while (servo_queue[channel].count())
    {
        /**
         * The interrupt will handle emptying of the queue
        check_servo_queue();
         */
        delayMicroseconds(servo_delays[channel] / 2);
    }
    //Serial.println("wait_for_servo: done");
}

inline void check_servo_queue()
{
    unsigned long time = micros();
    for (byte channel = 0; channel < SERVO_CHANNELS; channel++)
    {
        // TODO: Figure out some way to handle the timer roll-over which in some corner cased will mess this up
        if (time < servo_ready[channel])
        {
            // Servo not ready yet
            /*
            Serial.print("check_servo_queue: channel ");
            Serial.print(channel, DEC);
            Serial.println(" not ready yet");
            */
            continue;
        }
        if (servo_queue[channel].count() < 1)
        {
            /*
            Serial.print("check_servo_queue: channel ");
            Serial.print(channel, DEC);
            Serial.println(" has nothing to do");
            */
            // Nothing in queue
            continue;
        }

        boolean command_status = set_servo_position(channel, servo_queue[channel].dequeue());
    }
}

inline boolean set_servo_position(byte channel, int position)
{
    /*
    Serial.print("set_servo_position called channel ");
    Serial.print(channel, DEC);
    Serial.print(" position ");
    Serial.println(position, DEC);
    */

    if (channel >= SERVO_CHANNELS)
    {
        // channels start from 0 thus >=
        return false;
    }

     if (servo_reverse[channel])
     {
        position = 2000 - position;
     }
     else
     {
        position = 1000 + position;
     }


    // PONDER: add getbounds method to the servoshield library and use the actual bounds for calculations
    // Our input positions are 0-1000
    int travel = last_servo_value[channel] - position;
    last_servo_value[channel] = position;
    int pwmval;
    pwmval = servo_trim[channel] + position;
    
    /**
     * FIXME: figure out how to do array of pointers
    servo_ports[channel] = pwmval;
     */
    if (channel == 0)
    {
        OCR1A = pwmval;
    }
    else
    {
        OCR1B = pwmval;
    }

    /*
    Serial.print("set_servo_position: channel=");
    Serial.print(channel, DEC);
    Serial.print(" pwmval ");
    Serial.println(pwmval, DEC);
    */

    servo_ready[channel] = micros() + (abs(travel) * servo_delays[channel]);

    /*
    Serial.print("Servo ");
    Serial.print(channel, DEC);
    Serial.print(" set to position ");
    Serial.print(position, DEC);
    Serial.print(", travel ");
    Serial.println(travel, DEC);
    */
    
    return true;
}

inline float deg2rad(float deg)
{
    return deg * ( M_PI / 180.0 );
}

inline float rad2deg(float rad)
{
    return rad * ( 180.0 / M_PI );
}

