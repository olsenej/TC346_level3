/* Code provided by Brian Winn, adapted and modified by Edward Olsen */
package {
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	import flash.utils.getTimer;
	import flash.utils.Timer;
	import flash.geom.Point;
	import flash.ui.Keyboard;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	
	public class Main_new extends MovieClip {
		// hold references to the game screens
		var mainMenuScreen : MainMenuScreen;
		var gameOverScreen : GameOverScreen;
		
		// hold references to sounds
		var laserSfx : LaserSfx;
		
		// constants for balancing the game play
		static const shipRotationSpeed:Number = .3;
		static const rockSpeedStart:Number = .03;
		static const rockSpeedIncrease:Number = .02;
		
		static const trollSpeedStart: Number = .04;
		static const trollSpeedIncrease:Number = .02;
		static const trollRadius:Number = 7;
		
		
		static const missileSpeed:Number = .2;
		static const thrustPower:Number = .015;
		static const shipRadius:Number = 20;  // the pixel radius of the ship
		static const startingShips:uint = 3;  // how many ships the player starts with
		static const carMovement:Boolean = false;  // make true if you want the ship to move more like a car, false if move more like in space
		static const shipDrag:Number = 0.001; // works only for car movement
		static const maxVelocity:Number = 0.5; // works only for car movement
		
		
		// game objects
		private var ship:Ship;
		private var troll:Troll;
		private var rocks:Array;  // list of all the rocks in the game scene
		private var missiles:Array; // list of all the missiles in the game scene
		
		// animation timer
		private var lastTime:uint;
		
		// arrow keys
		private var rightArrow:Boolean = false;
		private var leftArrow:Boolean = false;
		private var upArrow:Boolean = false;
		private var downArrow:Boolean = false;
		private var brakeButt:Boolean = false;
		
		// ship velocity
		private var shipMoveX:Number;
		private var shipMoveY:Number;
		private var shipVelocity:Number;
		private var thurstRotation:Number = 0.0;
		private var shipAngle:Number = -90;
		
		// timers
		private var delayTimer:Timer;
		private var shieldTimer:Timer;
		
		// game mode
		private var gameMode:String;
		private var shieldOn:Boolean;
		
		// ships and shields
		private var shipsLeft:uint;
		private var shieldsLeft:uint;
		private var shipIcons:Array; // list of ship icons for removal later
		private var shieldIcons:Array; // list of shield icons for removal later
		private var scoreDisplay:TextField;

		// score and level
		private var gameScore:Number;
		private var gameLevel:uint;

		// sprites
		private var gameObjects:Sprite;
		private var scoreObjects:Sprite;
		
		// constructor function
		public function Main_new() {
			// setup game screens
			mainMenuScreen = new MainMenuScreen();
			gameOverScreen = new GameOverScreen();
			
			laserSfx = new LaserSfx();
			
			// setup game screen buttons
			mainMenuScreen.play_btn.addEventListener(MouseEvent.CLICK,onPlayButtonClick);
			gameOverScreen.playAgain_btn.addEventListener(MouseEvent.CLICK,onPlayAgainButtonClick);
			
			// open main menu screen
			addChild(mainMenuScreen);
		}
		
		function onPlayButtonClick(event:MouseEvent):void
			{
				removeChild(mainMenuScreen);
				startGame();
			}
			
			function onPlayAgainButtonClick(event:MouseEvent):void
			{
				removeChild(gameOverScreen);
				startGame();
			}
			
		// start the game
		function startGame() : void {
			// if you want a background to the game scene, add it here
			
			// setup the sprite that holds all of the game objects (ship, rocks, etc)
			gameObjects = new Sprite();
			addChild(gameObjects);
			
			// setup the sprite that holds the GUI (lives counter, score, etc)
			scoreObjects = new Sprite();
			addChild(scoreObjects);
			
			// reset score objects
			gameLevel = 1;
			shipsLeft = startingShips;
			gameScore = 0;
			createShipIcons();
			createScoreDisplay();

			// set up the main game loop
			addEventListener(Event.ENTER_FRAME,gameLoop);

			// make sure the stage has focus for keyboard input
			stage.focus = stage;

			// add keyboard event listeners for game controls
			stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDownFunction);
			stage.addEventListener(KeyboardEvent.KEY_UP,keyUpFunction);
			
			// start 
			gameMode = "delay";
			shieldOn = false;
			missiles = new Array();
			newShip(null);
			nextRockWave(null);
			nextTroll(null);
		}
		
		// KEYBOARD CONTROL
		
		// register key presses
		public function keyDownFunction(event:KeyboardEvent) {
			if (event.keyCode == Keyboard.LEFT) {
					leftArrow = true;
			} else if (event.keyCode == Keyboard.RIGHT) {
					rightArrow = true;
			} else if (event.keyCode == Keyboard.UP) {
					upArrow = true;
					// show thruster
					if (gameMode == "play") ship.gotoAndStop(2);
			} else if (event.keyCode == Keyboard.DOWN) {
					downArrow = true;
					//show opposite thrust
					if (gameMode == "play") ship.gotoAndStop(4);
			} else if (event.keyCode == Keyboard.SPACE) { // space
					if (gameMode == "play") newMissile();
			} else if (event.keyCode == 66) {
					brakeButt = true;
			}
		}
			
		// register key ups
		public function keyUpFunction(event:KeyboardEvent) {
			if (event.keyCode == Keyboard.LEFT) {
				leftArrow = false;
			} else if (event.keyCode == Keyboard.RIGHT) {
				rightArrow = false;
			} else if (event.keyCode == Keyboard.UP) {
				upArrow = false;
				// remove thruster
				if (gameMode == "play") ship.gotoAndStop(1);
			} else if (event.keyCode == Keyboard.DOWN) {
					downArrow = false;
			} else if (event.keyCode == 66) {
					brakeButt = false;
			}
		}
		
		// MAIN GAME LOOP
		
		public function gameLoop(event:Event) {
			// get timer difference (delta time) for motion
			var timePassed:uint = getTimer() - lastTime;
			lastTime += timePassed;

			// update position of game objects
			moveRocks(timePassed);
			moveTroll(timePassed);
			trace("troll x: ", troll.x);
			trace("troll y: ", troll.y);
			if (gameMode != "delay") {
				moveShip(timePassed);
			}
			
			moveMissiles(timePassed);
			
			
			// check for collisions
			checkCollisions();
			
			
		}

		public function endGame() {
			// remove all game objects
			removeChild(gameObjects);
			removeChild(scoreObjects);
			gameObjects = null;
			scoreObjects = null;
			
			// remove all game event listeners
			removeEventListener(Event.ENTER_FRAME,gameLoop);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN,keyDownFunction);
			stage.removeEventListener(KeyboardEvent.KEY_UP,keyUpFunction);
			
			// bring up the game over screen
			addChild(gameOverScreen);
		}

		
		// SCORE OBJECTS
		
		// draw number of ships left
		public function createShipIcons() {
			// create an array to keep track of the ship icons
			shipIcons = new Array();
			
			// for each ship
			for(var i:uint=0;i<shipsLeft;i++) {
				// create a new ship icon movie clip
				var newShip:ShipIcon = new ShipIcon();
				
				// set the position of the movieclip
				newShip.x = 20+i*15;
				newShip.y = 575;
				
				// add to the stage
				scoreObjects.addChild(newShip);
				
				// add to the array so we can keep track of it for removal later
				shipIcons.push(newShip);
			}
		}
		
		// draw number of shields left
		public function createShieldIcons() {
			// create an array to keep track of the shield icons
			shieldIcons = new Array();
			
			// for each shield
			for(var i:uint=0;i<shieldsLeft;i++) {
				// create a new shield icon movie clip
				var newShield:ShieldIcon = new ShieldIcon();
				
				// set the position of the movieclip
				newShield.x = 780-i*15;
				newShield.y = 575;
				
				// add to the stage
				scoreObjects.addChild(newShield);
				
				// add to the array so we can keep track of it for removal later
				shieldIcons.push(newShield);
			}
			
		}
		
		// put the numerical score at the upper right
		public function createScoreDisplay() {
			// create and setup the score display
			scoreDisplay = new TextField();
			scoreDisplay.x = 350;
			scoreDisplay.y = 10;
			scoreDisplay.width = 100;
			scoreDisplay.selectable = false;
			
			// create and setup the score display text format details
			var scoreDisplayFormat = new TextFormat();
			scoreDisplayFormat.color = 0xFFFFFF;
			scoreDisplayFormat.font = "Arial";
			scoreDisplayFormat.align = "right";
			
			// apply the text format to the score display
			scoreDisplay.defaultTextFormat = scoreDisplayFormat;

			// add the score display to the stage
			scoreObjects.addChild(scoreDisplay);

			// update the score so it displays the proper score
			updateScore();
		}
		
		// new score to show
		public function updateScore() {
			scoreDisplay.text = String(gameScore);
		}
		
		// remove the last ship icon in the shipIcons array (pop it off the array)
		public function removeShipIcon() {
			scoreObjects.removeChild(shipIcons.pop());
		}
		
		// remove the last ship icon in the shipIcons array (pop it off the array)
		public function removeShieldIcon() {
			scoreObjects.removeChild(shieldIcons.pop());
		}
		
		// remove all the remaining ship icons
		public function removeAllShipIcons() {
			while (shipIcons.length > 0) {
				removeShipIcon();
			}
		}
		
		// remove all the remaining shield icons
		public function removeAllShieldIcons() {
			while (shieldIcons.length > 0) {
				removeShieldIcon();
			}
		}
		
		
		// SHIP CREATION AND MOVEMENT
		
		// create a new ship
		public function newShip(event:TimerEvent) {
			// if ship exists, remove it
			if (ship != null) {
				gameObjects.removeChild(ship);
				ship = null;
			}
			
			// if no more ships, then game is over
			if (shipsLeft < 1) {
				endGame();
				return; // exit function early
			}
			
			// there must be ships left so create, position, and add new ship
			ship = new Ship();
			ship.gotoAndStop(1);
			ship.x = 400;
			ship.y = 300;
			ship.rotation = -90;  // rotate so it is facing up initially
			ship.shield.visible = false;
			gameObjects.addChild(ship);
			
			// set up ship properties
			shipMoveX = 0.0;
			shipMoveY = 0.0;
			shipVelocity = 0.0;
			gameMode = "play";
			
			// set up shields
			shieldsLeft = 3;
			createShieldIcons();
			
			// for all lives but the first start with a free shield
			if (shipsLeft != startingShips) {
				startShield(true);
			}
		}
				
		// animate ship
		public function moveShip(timeDiff:uint) {
			
			// rotate and thrust
			if (leftArrow) {
				ship.rotation -= shipRotationSpeed*timeDiff;
				shipAngle = ship.rotation;
			} else if (rightArrow) {
				ship.rotation += shipRotationSpeed*timeDiff;
				shipAngle = ship.rotation;
			} else if (upArrow) {
				// Space Movement: calculate the change of X and Y based on the angle of the ship and thrust
				shipMoveX += Math.cos(Math.PI*ship.rotation/180)*thrustPower*timeDiff;
				shipMoveY += Math.sin(Math.PI*ship.rotation/180)*thrustPower*timeDiff;
				
				// Car Movement: add thrust to the velocity
				shipVelocity += thrustPower;
			} else if (downArrow) {
				// Space Movement: calculate the change of X and Y based on the angle of the ship and thrust
				shipMoveX -= Math.cos(Math.PI*ship.rotation/180)*thrustPower*timeDiff;
				shipMoveY -= Math.sin(Math.PI*ship.rotation/180)*thrustPower*timeDiff;
				
				// Car Movement: add thrust to the velocity
				//shipVelocity -= thrustPower;
			} else if (brakeButt) {
				shipMoveX = shipMoveX/1.1;
				shipMoveY = shipMoveY/1.1;
			}
		
			if (carMovement) {
				// apply drag
				shipVelocity -= shipDrag;
				
				// make sure drag does not make ship move backwards
				if (shipVelocity<0) {
					shipVelocity = 0;
				}
				
				// make sure ship does not exceed max velocity
				if (shipVelocity>maxVelocity) {
					shipVelocity = maxVelocity;
				}
				
				// calculate change in x and y
				shipMoveX = Math.cos(Math.PI*ship.rotation/180)*shipVelocity*timeDiff;
				shipMoveY = Math.sin(Math.PI*ship.rotation/180)*shipVelocity*timeDiff;
			}
			// move
			ship.x += shipMoveX;
			ship.y += shipMoveY;
			
			// wrap around screen
			if ((shipMoveX > 0) && (ship.x > 820)) {
				ship.x -= 840;
			}
			if ((shipMoveX < 0) && (ship.x < -20)) {
				ship.x += 840;
			}
			if ((shipMoveY > 0) && (ship.y > 620)) {
				ship.y -= 640;
			}
			if ((shipMoveY < 0) && (ship.y < -20)) {
				ship.y += 640;
			}
		}
		
		// remove ship
		public function shipHit() {
			// update the shipsLeft counter
			shipsLeft--;
			
			// put the gameMode into a delay state
			gameMode = "delay";
			
			// play the ship explode animation
			ship.gotoAndPlay("explode");

			// remove all the ship and shield icons (they will be redrawn for the next ship)
			removeAllShieldIcons();
			removeShipIcon();
			
			// start a delay timer for when the next ship appears
			delayTimer = new Timer(2000,1);
			delayTimer.addEventListener(TimerEvent.TIMER_COMPLETE,newShip);
			delayTimer.start();			
		}
		
		// turn on shield for 3 seconds
		public function startShield(freeShield:Boolean) {
			if (shieldsLeft < 1) return; // no shields left
			if (shieldOn) return; // shield already on
			
			// turn on shield
			shieldOn = true;
			ship.shield.visible = true;

			// update shields remaining
			if (!freeShield) {
				removeShieldIcon();
				shieldsLeft--;
			}

			// set timer to turn off the shield after 3 seconds
			shieldTimer = new Timer(3000,1);
			shieldTimer.addEventListener(TimerEvent.TIMER_COMPLETE,endShield);
			shieldTimer.start();
		}
		
		// turn off shield
		public function endShield(event:TimerEvent) {
			ship.shield.visible = false;
			shieldOn = false;
		}
		
		// ROCKS		
		
		// create a single rock of a specific size
		public function newRock(x,y:int, rockType:String) {
			
			// create a new movieclip of the appropriate size.  Also set the radius based on the size
			var newRock:MovieClip;
			var rockRadius:Number;
			
			if (rockType == "Big") {
				newRock = new Rock_Big();
				rockRadius = 35;
			} else if (rockType == "Medium") {
				newRock = new Rock_Medium();
				rockRadius = 20;
			} else if (rockType == "Small") {
				newRock = new Rock_Small();
				rockRadius = 10;
			}
												
			// set start position
			newRock.x = x;
			newRock.y = y;
			
			// set random movement and rotation
			var dx:Number = Math.random()*2.0-1.0;
			var dy:Number = Math.random()*2.0-1.0;
			var dr:Number = Math.random();
			
			// add to stage
			gameObjects.addChild(newRock);
			
			// add to the rock list so we can access it later
			rocks.push({rock:newRock, dx:dx, dy:dy, dr:dr, rockType:rockType, rockRadius: rockRadius});
		}
		
		// create four rocks
		public function nextRockWave(event:TimerEvent) {
			// create a new array to hold the rocks
			rocks = new Array();
			
			// create the derps
			newRock(100,100,"Big");
			newRock(100,300,"Big");
			newRock(450,100,"Big");
			newRock(450,300,"Big");
			
			// set the gameMode to play
			gameMode = "play";
			
			// if beyond level 1, give the player a free shield in case the new rocks appear right on top of the ship
			if (gameLevel>1) { 
				startShield(true);
			}
		}
		
	
		// animate all rocks
		public function moveRocks(timeDiff:uint) {
			// for each rock in the rock array (from last to first)
			for(var i:int=rocks.length-1;i>=0;i--) {
								
				// move the rocks
				var rockSpeed:Number = rockSpeedStart + rockSpeedIncrease*gameLevel;
				rocks[i].rock.x += rocks[i].dx*timeDiff*rockSpeed;
				rocks[i].rock.y += rocks[i].dy*timeDiff*rockSpeed;
				
				// rotate rocks
				rocks[i].rock.rotation += rocks[i].dr*timeDiff*rockSpeed;
				
				// wrap rocks
				if ((rocks[i].dx > 0) && (rocks[i].rock.x > 820)) {
					rocks[i].rock.x -= 840;
				}
				if ((rocks[i].dx < 0) && (rocks[i].rock.x < -20)) {
					rocks[i].rock.x += 840;
				}
				if ((rocks[i].dy > 0) && (rocks[i].rock.y > 620)) {
					rocks[i].rock.y -= 640;
				}
				if ((rocks[i].dy < 0) && (rocks[i].rock.y < -20)) {
					rocks[i].rock.y += 640;
				}
			}
		}
		
		public function rockHit(rockNum:uint) {
			// create two smaller rocks
			if (rocks[rockNum].rockType == "Big") {
				newRock(rocks[rockNum].rock.x,rocks[rockNum].rock.y,"Medium");
				newRock(rocks[rockNum].rock.x,rocks[rockNum].rock.y,"Medium");
			} else if (rocks[rockNum].rockType == "Medium") {
				newRock(rocks[rockNum].rock.x,rocks[rockNum].rock.y,"Small");
				newRock(rocks[rockNum].rock.x,rocks[rockNum].rock.y,"Small");
			}
			// remove original rock from the stage and the array
			gameObjects.removeChild(rocks[rockNum].rock);
			rocks.splice(rockNum,1);
		}

		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// TROLL ALERT
			
		
		// create a single troll
		public function newTroll(x,y:int) {
			
			// create a new movieclip of the appropriate size.  Also set the radius based on the size
			//var aTroll:MovieClip;
					
			troll = new Troll();
			
			// set start position
			troll.x = x;
			troll.y = y;			
		}
		
		// create a troll
		public function nextTroll(event:TimerEvent) {
			
			// create the troll
			newTroll(1100,1100);
			
			// set the gameMode to play
			//gameMode = "play";
			
			gameObjects.addChild(troll);
				
		}
			
		function FaceAndMove(me, you, mySpeed)
		{
			
			var opposite:Number = ship.y - troll.y;
			
			var adjacent:Number = you.x - troll.x; 
			var radians:Number = Math.atan2(opposite, adjacent);
			var degrees:Number = radians * (180 / Math.PI ) - 90;
			
			troll.rotation = degrees;
			troll.x += Math.cos(radians) * mySpeed;
			troll.y += Math.sin(radians) * mySpeed;
			
			
			// wrap troll
			if (troll.x > 820) {
				troll.x -= 840;
			}
			if (troll.x < -20) {
				troll.x += 840;
			}
			if (troll.y > 620) {
				troll.y -= 640;
			}
			if (troll.y < -20) {
				troll.y += 640;
			}
			
		}
		
		//move a troll
		public function moveTroll(timeDiff:uint) {
			var trollSpeed:Number = ( trollSpeedStart + trollSpeedIncrease*gameLevel ) * timeDiff;
			FaceAndMove(troll, ship, trollSpeed);
			
		}
		
		//hit a troll
		public function trollHit() {
		
			// remove troll from stage
			//gameObjects.removeChild(troll);
			//trace("troll removed");
			
		}
		
		


		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		// MISSILES
		
		// create a new Missile
		public function newMissile() {
			// play sound and keep reference to it just in case you want to modify the volume
			var shotsound : SoundChannel = laserSfx.play();
			
			// play back at 50% volume
			shotsound.soundTransform = new SoundTransform(0.5,0);
			
			// create
			var newMissile:Missile = new Missile();
			
			// set direction
			newMissile.dx = Math.cos(Math.PI*ship.rotation/180);
			newMissile.dy = Math.sin(Math.PI*ship.rotation/180);
			
			// placement
			newMissile.x = ship.x + newMissile.dx*shipRadius;
			newMissile.y = ship.y + newMissile.dy*shipRadius;
			newMissile.rotation = shipAngle;
	
			// add to stage and array
			gameObjects.addChild(newMissile);
			missiles.push(newMissile);
		}
		
		// animate missiles
		public function moveMissiles(timeDiff:uint) {
			// for each missile that has been created
			for(var i:int=missiles.length-1;i>=0;i--) {
				// move
				missiles[i].x += missiles[i].dx*missileSpeed*timeDiff;
				missiles[i].y += missiles[i].dy*missileSpeed*timeDiff;
				// moved off screen
				if ((missiles[i].x < 0) || (missiles[i].x > 550) || (missiles[i].y < 0) || (missiles[i].y > 400)) {
					// remove from stage
					gameObjects.removeChild(missiles[i]);
					
					// remove from the missiles array
					missiles.splice(i,1);
				}
			}
		}
			
		// remove a missile and the array
		public function missileHit(missileNum:uint) {
			gameObjects.removeChild(missiles[missileNum]);
			missiles.splice(missileNum,1);
		}
		
		// COLLISION DETECTION
		
		public function checkCollisions() {
			
				
			
			// check for troll hitting ship
				if (gameMode == "play") {
					if (shieldOn == false) { // only if shield is off
						// collision detection (see if the position of ship is less than the radius of the rock)
						// this is fast and works well since the rocks are basically a circle
						//if (Point.distance(new Point(rocks[j].rock.x,rocks[j].rock.y), new Point(ship.x,ship.y)) < rocks[j].rockRadius+shipRadius) {
						
								if (Point.distance(new Point(troll.x,troll.y), new Point(ship.x,ship.y))< 7+shipRadius){
									// remove ship and troll
									shipHit();
									trollHit();
						}
					}
				}
			
			
			// loop through rocks to check for missile hits
			/*rockloop:*/ for(var j:int=rocks.length-1;j>=0;j--) {
				// loop through missiles
				missileloop: for(var i:int=missiles.length-1;i>=0;i--) {
					// collision detection (see if the position of each is less than the radius of the rock)
					// this is fast and works well since the rocks are basically a circle
		//			//if (Point.distance(27 < rocks[j].rockRadius)) {
					// Below are two other collision detection techniques we could have used:
					if (rocks[j].rock.hitTestObject(missiles[i])) {
					//if (rocks[j].rock.hitTestPoint(missiles[i].x,missiles[i].y,true)) {

						// remove rock and missile
						rockHit(j);
						missileHit(i);
						
						// add score
						gameScore += 1337;
						updateScore();
						
						// since this rock has been hit, break out of this loop and continue next rock
						//continue rockloop;
					}
				}
				
				// check for rock hitting ship
				if (gameMode == "play") {
					if (shieldOn == false) { // only if shield is off
						// collision detection (see if the position of ship is less than the radius of the rock)
						// this is fast and works well since the rocks are basically a circle
						if (Point.distance(new Point(rocks[j].rock.x,rocks[j].rock.y), new Point(ship.x,ship.y))< rocks[j].rockRadius+shipRadius) {
							
							// remove ship and rock
							shipHit();
							rockHit(j);
						}
					}
									
						
						
					
				}
			}
			
			// if all out of rocks, change game mode and trigger more
			if ((rocks.length == 0) && (gameMode == "play")) {
				gameMode = "betweenlevels";
				gameLevel++; // advance a level
				
				// setup timer to start next wave of rocks
				delayTimer = new Timer(2000,1);
				delayTimer.addEventListener(TimerEvent.TIMER_COMPLETE,nextRockWave);
				delayTimer.addEventListener(TimerEvent.TIMER_COMPLETE,nextTroll);
				gameObjects.removeChild(troll);
				delayTimer.start();
			}
		}
		
	}
}
