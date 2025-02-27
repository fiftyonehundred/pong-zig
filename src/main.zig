const rl = @import("raylib");
const std = @import("std");

const SCREEN_TITLE = "Pong";
const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 480;

const TARGET_FPS = 60;

const BACKGROUND_COLOR = rl.Color.init(2, 6, 23, 255);
const FOREGROUND_COLOR = rl.Color.init(248, 250, 252, 255);
const MIDDLEGROUND_COLOR = rl.Color.init(71, 85, 105, 255);
const TITLE_COLOR = rl.Color.init(250, 204, 21, 255);

const LR_PADDING = 10;

const MAX_SCORE = 11;

const GameState = enum {
    menu,
    start,
    game,
    pause,
    player_wins,
    opponent_wins,
};

const GameDifficulty = enum {
    easy,
    medium,
    hard,

    pub fn getOpponentSpeed(self: GameDifficulty) f32 {
        switch (self) {
            .easy => return 40,
            .medium => return 90,
            .hard => return 140,
        }
    }
};

const Ball = struct {
    rect: rl.Rectangle,
    speed: f32,
    direction: rl.Vector2,
    color: rl.Color,
};

const Paddle = struct {
    rect: rl.Rectangle,
    speed: f32,
    color: rl.Color,
};

var state: GameState = .menu;
var game_difficulty: GameDifficulty = undefined;

var ball: Ball = undefined;

var player_paddle: Paddle = undefined;
var player_score: u16 = 0;

var opponent_paddle: Paddle = undefined;
var opponent_score: u16 = 0;

pub fn init() void {
    // Initializing the ball
    const ball_size = 10;
    const random_ball_y: f32 = @floatFromInt(rl.getRandomValue(-1, 1));
    ball = Ball{
        .rect = rl.Rectangle{
            .x = SCREEN_WIDTH / 2 - ball_size / 2,
            .y = SCREEN_HEIGHT / 2 - ball_size / 2,
            .width = ball_size,
            .height = ball_size,
        },
        .speed = 240,
        .direction = rl.Vector2{ .x = 1, .y = random_ball_y },
        .color = FOREGROUND_COLOR,
    };

    // Initializing the player's paddle
    const player_paddle_width = 10;
    const player_paddle_height = 64;
    player_paddle = Paddle{
        .rect = rl.Rectangle{
            .x = SCREEN_WIDTH - LR_PADDING - player_paddle_width,
            .y = SCREEN_HEIGHT / 2 - player_paddle_height / 2,
            .width = player_paddle_width,
            .height = player_paddle_height,
        },
        .speed = 240,
        .color = FOREGROUND_COLOR,
    };

    // Initializing the opponent's paddle
    const opponent_paddle_width = 10;
    const opponent_paddle_height = 64;
    const opponent_speed = game_difficulty.getOpponentSpeed();
    opponent_paddle = Paddle{
        .rect = rl.Rectangle{
            .x = LR_PADDING,
            .y = SCREEN_HEIGHT / 2 - opponent_paddle_height / 2,
            .width = opponent_paddle_width,
            .height = opponent_paddle_height,
        },
        .speed = opponent_speed,
        .color = FOREGROUND_COLOR,
    };
}

pub fn draw() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(BACKGROUND_COLOR);

    // Draws the score
    const score_font_size = 40;
    rl.drawText(rl.textFormat("%i", .{opponent_score}), 100, SCREEN_HEIGHT / 2 - score_font_size / 2, score_font_size, MIDDLEGROUND_COLOR);
    rl.drawText(rl.textFormat("%i", .{player_score}), SCREEN_WIDTH - 100, SCREEN_HEIGHT / 2 - score_font_size / 2, score_font_size, MIDDLEGROUND_COLOR);

    // Draws the entities ball, player, and opponent
    rl.drawRectangleRec(ball.rect, ball.color);
    rl.drawRectangleRec(player_paddle.rect, player_paddle.color);
    rl.drawRectangleRec(opponent_paddle.rect, opponent_paddle.color);
}

pub fn update() void {
    const dt = rl.getFrameTime();

    // Allows player to move up and down until they hit the wall
    if (rl.isKeyDown(.up)) {
        const next_position = player_paddle.rect.y - player_paddle.speed * dt;
        if (next_position >= 0) {
            player_paddle.rect.y = next_position;
        } else {
            player_paddle.rect.y = 0;
        }
    } else if (rl.isKeyDown(.down)) {
        const next_position = player_paddle.rect.y + player_paddle.speed * dt;
        if (next_position <= SCREEN_HEIGHT - player_paddle.rect.height) {
            player_paddle.rect.y = next_position;
        } else {
            player_paddle.rect.y = SCREEN_HEIGHT - player_paddle.rect.height;
        }
    }

    // Make opponent move up and down by following the ball
    if (ball.rect.y < opponent_paddle.rect.y) {
        const next_position = opponent_paddle.rect.y - opponent_paddle.speed * dt;
        if (next_position >= 0) {
            opponent_paddle.rect.y = next_position;
        } else {
            opponent_paddle.rect.y = 0;
        }
    } else if (ball.rect.y > opponent_paddle.rect.y) {
        const next_position = opponent_paddle.rect.y + opponent_paddle.speed * dt;
        if (next_position <= SCREEN_HEIGHT - opponent_paddle.rect.height) {
            opponent_paddle.rect.y = next_position;
        } else {
            opponent_paddle.rect.y = SCREEN_HEIGHT - opponent_paddle.rect.height;
        }
    }

    // Ball collision check and bounce with top and bottom walls
    if (ball.rect.y <= 0) {
        ball.direction.y *= -1;
    } else if (ball.rect.y >= SCREEN_HEIGHT - ball.rect.height) {
        ball.direction.y *= -1;
    }

    // Ball collision check and bounce with player's paddle
    if (rl.checkCollisionRecs(ball.rect, player_paddle.rect)) {
        // Makes ball bounce horizontally from paddle
        ball.direction.x *= -1;

        // Calculates how far the ball is away from the paddle's center:
        // * If the ball hits the center then this will result to zero, since there's no distance between them
        // * If the ball hits the upper side then this will result to a negative number
        // * If the ball hits the lower side then this will result to a positive number
        const ball_center = ball.rect.y + ball.rect.height / 2;
        const player_paddle_center = player_paddle.rect.y + player_paddle.rect.height / 2;
        const hit_position = (ball_center - player_paddle_center) / (player_paddle.rect.height / 2);

        // Sets the paddle's y direction based on previous calculation
        ball.direction.y = hit_position;

        // Since we don't know if the ball is inside the paddle or not
        // We use this to make sure the ball is not stuck inside
        ball.rect.x = player_paddle.rect.x - ball.rect.width - 1;
    }

    // Ball collision check and bounce with opponent's paddle
    if (rl.checkCollisionRecs(ball.rect, opponent_paddle.rect)) {
        ball.direction.x *= -1;

        const ball_center = ball.rect.y + ball.rect.height / 2;
        const opponent_paddle_center = opponent_paddle.rect.y + opponent_paddle.rect.height / 2;
        const hit_position = (ball_center - opponent_paddle_center) / (opponent_paddle.rect.height / 2);

        ball.direction.y = hit_position;
        ball.rect.x = opponent_paddle.rect.x + ball.rect.width + 1;
    }

    // Moves the ball
    ball.rect.x += ball.speed * ball.direction.x * dt;
    ball.rect.y += ball.speed * ball.direction.y * dt;

    // Checks if ball is out of bounds, if so, add score to who won the point, then restart position
    if (ball.rect.x > SCREEN_WIDTH) {
        opponent_score += 1;
        state = .start;
    } else if (ball.rect.x < 0 - ball.rect.width) {
        player_score += 1;
        state = .start;
    }
}

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_TITLE);
    defer rl.closeWindow();

    rl.setTargetFPS(TARGET_FPS);

    while (!rl.windowShouldClose()) {
        switch (state) {
            .menu => {
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(BACKGROUND_COLOR);

                // Draws the main menu
                const header_font_size = 64;
                const font_size = 16;
                const padding = 10;
                rl.drawText(
                    "Pong",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Pong", header_font_size), 2),
                    SCREEN_HEIGHT / 2 - header_font_size / 2,
                    header_font_size,
                    TITLE_COLOR,
                );
                rl.drawText(
                    "Press 1 for Easy",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Press 1 for Easy", font_size), 2),
                    SCREEN_HEIGHT / 2 - font_size / 2 + header_font_size + padding,
                    font_size,
                    FOREGROUND_COLOR,
                );
                rl.drawText(
                    "Press 2 for Medium",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Press 2 for Medium", font_size), 2),
                    SCREEN_HEIGHT / 2 - font_size / 2 + (header_font_size + font_size) + padding,
                    font_size,
                    FOREGROUND_COLOR,
                );
                rl.drawText(
                    "Press 3 for Hard",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Press 3 for Hard", font_size), 2),
                    SCREEN_HEIGHT / 2 - font_size / 2 + (header_font_size + font_size * 2) + padding,
                    font_size,
                    FOREGROUND_COLOR,
                );

                // Main menu difficulty selector
                if (rl.isKeyPressed(.one)) {
                    game_difficulty = .easy;
                    state = .start;
                } else if (rl.isKeyPressed(.two)) {
                    game_difficulty = .medium;
                    state = .start;
                } else if (rl.isKeyPressed(.three)) {
                    game_difficulty = .hard;
                    state = .start;
                }
            },
            .start => {
                init();
                draw();

                if (rl.isKeyPressed(.space)) {
                    state = .game;
                }
            },
            .game => {
                draw();
                update();

                if (player_score == MAX_SCORE) {
                    state = .player_wins;
                } else if (opponent_score == MAX_SCORE) {
                    state = .opponent_wins;
                }

                if (rl.isKeyPressed(.p)) {
                    state = .pause;
                }
            },
            .pause => {
                draw();

                if (rl.isKeyPressed(.p)) {
                    state = .game;
                }
            },
            .player_wins => {
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(BACKGROUND_COLOR);

                // Draws "Player wins!" on the screen
                const header_font_size = 32;
                const font_size = 16;
                rl.drawText(
                    "Player wins!",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Player wins!", header_font_size), 2),
                    SCREEN_HEIGHT / 2 - header_font_size / 2,
                    header_font_size,
                    TITLE_COLOR,
                );
                rl.drawText(
                    "Press Enter to go back to main menu",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Press Enter to go back to main menu", font_size), 2),
                    SCREEN_HEIGHT / 2 + header_font_size,
                    font_size,
                    FOREGROUND_COLOR,
                );

                if (rl.isKeyPressed(.enter)) {
                    player_score = 0;
                    opponent_score = 0;
                    state = .menu;
                }
            },
            .opponent_wins => {
                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(BACKGROUND_COLOR);

                // Draws "Opponent wins!" on the screen
                const header_font_size = 32;
                const font_size = 16;
                rl.drawText(
                    "Opponent wins!",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Opponent wins!", header_font_size), 2),
                    SCREEN_HEIGHT / 2 - header_font_size / 2,
                    header_font_size,
                    TITLE_COLOR,
                );
                rl.drawText(
                    "Press Enter to go back to main menu",
                    SCREEN_WIDTH / 2 - @divTrunc(rl.measureText("Press Enter to go back to main menu", font_size), 2),
                    SCREEN_HEIGHT / 2 + header_font_size,
                    font_size,
                    FOREGROUND_COLOR,
                );

                if (rl.isKeyPressed(.enter)) {
                    player_score = 0;
                    opponent_score = 0;
                    state = .menu;
                }
            },
        }
    }
}
