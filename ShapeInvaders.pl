#!/usr/bin/perl

use strict;
use warnings;
use Curses;

# Set up the terminal
initscr();
start_color();    # Enable colors
use_default_colors();
init_pair(1, COLOR_WHITE, COLOR_BLACK);
init_pair(2, COLOR_RED, COLOR_BLACK);  # Define a red color pair
attrset(COLOR_PAIR(1));
curs_set(0);      # Hide the cursor
keypad(1);        # Enable special keys
timeout(100);     # Set a timeout for non-blocking input
bkgd(' ' | COLOR_PAIR(1));  # Set background color

# Initial spaceship position
my $spaceship_x = 10;
my $spaceship_y = 20;
my $spaceship_rotation = 0;  # Rotation angle (0, 90, 180, 270 degrees)

# Arrays to store active bullets
my @bullets;       # For normal speed
my @leftBullets;   # For leftward bullets
my @rightBullets;  # For rightward bullets

# Arrays to store active squares
my @squares;

# Set the speed multipliers for bullets
my $speed_multiplier = 2;
my $left_speed_multiplier = 3;
my $right_speed_multiplier = 3;

# Timer variables for spawning squares
my $spawn_timer = 0;
my $spawn_interval = 5;  # 5 seconds interval

# Score variable
my $score = 0;

# Collision detection range
my $collision_range = 2;

# Game loop
while (1) {
    # Get user input
    my $key = getch();

    # Quit the game if 'q' is pressed
    last if defined $key && $key eq 'q';

    # Rotate the spaceship 90 degrees counterclockwise
    $spaceship_rotation = ($spaceship_rotation + 90) % 360 if defined $key && $key eq 'a';

    # Rotate the spaceship 90 degrees clockwise
    $spaceship_rotation = ($spaceship_rotation - 90) % 360 if defined $key && $key eq 'd';

    # Move the spaceship left
    $spaceship_x-- if defined $key && $key == KEY_LEFT && $spaceship_x > 0;

    # Move the spaceship right
    $spaceship_x++ if defined $key && $key == KEY_RIGHT && $spaceship_x < COLS() - 1;

    # Move the spaceship up
    $spaceship_y-- if defined $key && $key == KEY_UP && $spaceship_y > 0;

    # Move the spaceship down
    $spaceship_y++ if defined $key && $key == KEY_DOWN && $spaceship_y < LINES() - 1;

    # Shoot a new bullet whenever the space bar is pressed
    if (defined $key && $key eq ' ') {
        my ($dx, $dy) = get_direction($spaceship_rotation);
        my $bullet_x = $spaceship_x;
        my $bullet_y = $spaceship_y;

        if ($dx == 0) {
            # Normal speed bullets
            push @bullets, { x => $bullet_x, y => $bullet_y, dx => $dx * $speed_multiplier, dy => $dy * $speed_multiplier };
        } elsif ($dx < 0) {
            # Leftward bullets
            push @leftBullets, { x => $bullet_x, y => $bullet_y, dx => $dx * $left_speed_multiplier, dy => $dy * $left_speed_multiplier };
        } else {
            # Rightward bullets
            push @rightBullets, { x => $bullet_x, y => $bullet_y, dx => $dx * $right_speed_multiplier, dy => $dy * $right_speed_multiplier };
        }
    }

    # Spawn squares every 5 seconds
    $spawn_timer++;
    if ($spawn_timer >= $spawn_interval * 10) {  # Multiply by 10 to match the timeout interval
        spawn_square();
        $spawn_timer = 0;
    }

    # Move all active bullets
    @bullets = move_bullets(@bullets);
    @leftBullets = move_bullets(@leftBullets);
    @rightBullets = move_bullets(@rightBullets);

    # Move all active squares
    @squares = move_squares(@squares);

    # Draw the spaceship
    clear();
    draw_spaceship($spaceship_x, $spaceship_y, $spaceship_rotation);

    # Draw all active bullets
    draw_bullets(@bullets);
    draw_bullets(@leftBullets);
    draw_bullets(@rightBullets);

    # Draw all active squares
    draw_squares(@squares);

    addstr(0, 0, "Score: $score");

    check_collisions(@bullets);
    check_collisions(@leftBullets);
    check_collisions(@rightBullets);

    # Refresh the screen
    refresh();
}

# Clean up and exit
endwin();

# Subroutine to get the direction based on the rotation angle
sub get_direction {
    my ($rotation) = @_;
    if ($rotation == 0) {
        return (0, -1);    # Up
    } elsif ($rotation == 90) {
        return (-1, 0);     # Left
    } elsif ($rotation == 180) {
        return (0, 1);     # Down
    } elsif ($rotation == 270) {
        return (1, 0);    # Right
    }

    # Default direction if rotation angle is not recognized
    return (0, -1); # Up by default
}

# Subroutine to move bullets
sub move_bullets {
    my (@bullets) = @_;
    return grep {
        $_->{x} += $_->{dx};
        $_->{y} += $_->{dy};
        $_->{y} >= 0 && $_->{y} < LINES() && $_->{x} >= 0 && $_->{x} < COLS();
    } @bullets;
}

# Subroutine to move squares
sub move_squares {
    my (@squares) = @_;
    return grep {
        $_->{y} += 1;  # Move squares downward
        $_->{y} >= 0 && $_->{y} < LINES();
    } @squares;
}

# Subroutine to draw the spaceship
sub draw_spaceship {
    my ($x, $y, $rotation) = @_;
    if ($rotation == 0) {
        addch($y, $x, ACS_UARROW() | A_BOLD);
    } elsif ($rotation == 90) {
        addch($y, $x, ACS_LARROW() | A_BOLD);
    } elsif ($rotation == 180) {
        addch($y, $x, ACS_DARROW() | A_BOLD);
    } elsif ($rotation == 270) {
        addch($y, $x, ACS_RARROW() | A_BOLD);
    }
}

# Subroutine to draw bullets
sub draw_bullets {
    my (@bullets) = @_;
    for my $bullet (@bullets) {
        addch($bullet->{y}, $bullet->{x}, ACS_BULLET() | A_BOLD);
    }
}

# Subroutine to draw squares
sub draw_squares {
    my (@squares) = @_;
    for my $square (@squares) {
        attrset(COLOR_PAIR(2));  # Use the red color pair
        addch($square->{y}, $square->{x}, ACS_CKBOARD() | COLOR_PAIR(2) | A_BOLD);
        attrset(COLOR_PAIR(1));  # Reset color to the default white/black pair
    }
}

# Subroutine to spawn squares
sub spawn_square {
    my $square_x = int(rand(COLS()));
    push @squares, { x => $square_x, y => 0 };  # Spawn the square at the top of the screen
}

# Subroutine to check for collisions between bullets and squares
sub check_collisions {
    my (@bullets) = @_;
    my @new_squares;

    for my $square (@squares) {
        my $collision = 0;

        for my $bullet (@bullets) {
            if (abs($square->{x} - $bullet->{x}) < $collision_range && abs($square->{y} - $bullet->{y}) < $collision_range) {
                # Collision detected, handle it here (e.g., remove both bullet and square)
                $collision = 1;
                $score += 100;
                last;  # Exit the inner loop once a collision is found
            }
        }

        push @new_squares, $square unless $collision;
    }

    @squares = @new_squares;
}
