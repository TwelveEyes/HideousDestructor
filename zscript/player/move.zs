// ------------------------------------------------------------
// Movement checks.
// ------------------------------------------------------------
const HDCONST_MAXFOCUSSCALE=0.99;
extend class HDPlayerPawn{
	//input is no longer considered in CheckPitch since it's already in HD's TurnCheck.
	override void CheckPitch(){
		if(player.centering){
			if (abs(Pitch)>2.){
				Pitch*=(2./3.);
			}else{
				Pitch=0.;
				player.centering = false;
				if(PlayerNumber()==consoleplayer)LocalViewPitch=0;
			}
		}else pitch=clamp(pitch,player.minpitch,player.maxpitch);
	}
	override void CheckCrouch(bool totallyfrozen){}
	void CrouchCheck(){
		if(CheckFrozen())return;
		let player=self.player;
		UserCmd cmd=player.cmd;
		if(CanCrouch()&&player.health>0){ //guess what i deleted lololol
			int crouchdir=player.crouching;
			if(!crouchdir){
				crouchdir=(cmd.buttons & BT_CROUCH)?-1:1;
			}
			else if(cmd.buttons & BT_CROUCH){
				player.crouching=0;
			}
			if(crouchdir==1 && player.crouchfactor<1 && pos.z+height<ceilingz){
				CrouchMove(1);
			}
			else if (crouchdir==-1 && player.crouchfactor>0.5){
				CrouchMove(-1);
			}
		}else player.Uncrouch();
		player.crouchoffset=-(viewheight)*(1-player.crouchfactor);
	}
	override void CrouchMove(int direction){
		let player=self.player;
		bool notpredicting=!(player.cheats & CF_PREDICTING);

		double defaultheight = FullHeight;
		double savedheight = Height;
		double crouchspeed = direction*CROUCHSPEED;
		double oldheight = player.viewheight;

		crouchspeed*=clamp(
			(health+100)*0.6
			-(direction==1?overloaded*3:overloaded*0.5)
			-(fatigue>20?fatigue*2:fatigue)
			-((stunned&&direction==1)?80:0)
			+stimcount+zerk*0.04,
			40,zerk>0?999:144
		)*0.01;

		player.crouchdir=direction;
		player.crouchfactor+=crouchspeed;

		// check whether the move is ok
		Height = defaultheight * player.crouchfactor;
		if(!TryMove(Pos.XY, false, NULL)){
			Height = savedheight;
			if (direction > 0){
				// doesn't fit
				player.crouchfactor -= crouchspeed;
				return;
			}
		}else if(notpredicting){
			if(!(level.time%10))fatigue++;
			if(player.onground && zerk>0 && direction>0 && height<fullheight*0.6)vel.z+=4;
		}
		Height = savedheight;

		player.crouchfactor = clamp(player.crouchfactor, 0.5, 1.);
		player.viewheight = ViewHeight * player.crouchfactor;
		player.crouchviewdelta = player.viewheight - ViewHeight;

		// Check for eyes going above/below fake floor due to crouching motion.
		CheckFakeFloorTriggers(pos.Z + oldheight, true);

		if(notpredicting)gunbraced=false;
	}
	override void MovePlayer(){
		let player = self.player;
		if(!player)return;
		UserCmd cmd = player.cmd;
		bool notpredicting = !(player.cheats & CF_PREDICTING);

		//update lastpitch and lastangle if teleported
		if(notpredicting&&teleported){
			lastpitch=pitch;
			lastangle=angle;
		}

		//cache cvars as necessary
		if(!hd_nozoomlean)cachecvars();

		//set up leaning
		double leanamt=leaned?(10./(3+checkencumbrance())):0;
		if(
			hdweapon(player.readyweapon)
		){
			leanamt*=8./max(8.,hdweapon(player.readyweapon).gunmass());
		}
		int leanmove=0;
		if(
			cmdleanmove&HDCMD_LEFT
			&&(
				leaned<=0
				||cmdleanmove&HDCMD_RIGHT
			)
		)leanmove--;
		if(
			cmdleanmove&HDCMD_RIGHT
			&&(
				leaned>=0
				||cmdleanmove&HDCMD_LEFT
			)
		)leanmove++;
		if(
			!leanmove&&(
				cmdleanmove&HDCMD_STRAFE
				||(
					cmd.buttons&BT_ZOOM
					&&!hd_nozoomlean.getbool()
				)
			)
		){
			if(cmd.sidemove<0&&leaned<=0)leanmove--;
			if(cmd.sidemove>0&&leaned>=0)leanmove++;
			cmd.sidemove=0;
		}


		//HD's handling of voluntary player turning.
		let readyweapon=player.readyweapon;
		if(readyweapon){
			double turnscale=1.;

			if(mousehijacked){
				readyweapon.lookscale=0.00001;
			}
			//reduced turning while supported.
			else if(
				isFocussing
				&&!countinv("IsMoving")
			){
				double aimscale=hd_aimsensitivity.GetFloat();
				if(aimscale>1.)aimscale=0.1;
				if(!gunbraced)aimscale+=(1.-aimscale)*0.3;
				else aimscale=min(aimscale,hd_bracesensitivity.GetFloat());
				turnscale*=clamp(aimscale,0.05,HDCONST_MAXFOCUSSCALE);
			}
			//reduced turning while crouched.
			else if(player.crouchfactor<0.7){
				int absch=max(abs(player.cmd.yaw),abs(player.cmd.pitch));
				if(absch>(8*65536/360)){
					turnscale*=0.6;
				}
			}
			//reduced turning while stunned.
			//all randomizing and inertia effects are in TurnCheck.
			if(stunned)turnscale*=0.3;

			//apply input
			double anglechange=clamp((360./65536.)*player.cmd.yaw,-40,40);
			if(notpredicting){
				lastpitch=pitch;
				lastangle=angle;
				if(player.turnticks){
					player.turnticks--;
					anglechange+=(180./TURN180_TICKS);
				}
			}
			readyweapon.lookscale=turnscale;
			player.fov=player.desiredfov*recoilfov;
			if(!mousehijacked){
				A_SetAngle(angle+anglechange,SPF_INTERPOLATE);
				A_SetPitch(clamp(pitch-(360./65536.)*player.cmd.pitch,player.minpitch,player.maxpitch),SPF_INTERPOLATE);
			}
		}


		player.onground = (pos.z <= floorz) || bOnMobj || bMBFBouncer || (player.cheats & CF_NOCLIP2);

		// killough 10/98:
		//
		// We must apply thrust to the player and bobbing separately, to avoid
		// anomalies. The thrust applied to bobbing is always the same strength on
		// ice, because the player still "works just as hard" to move, while the
		// thrust applied to the movement varies with 'movefactor'.

		if(!movehijacked&&(cmd.forwardmove||cmd.sidemove||leanmove)){
			double forwardmove=0;double sidemove=0;
			double bobfactor=0;
			double friction=0;double movefactor=0;
			double fm=0;double sm=0;

			[friction, movefactor] = GetFriction();
			bobfactor = friction < ORIG_FRICTION ? movefactor : ORIG_FRICTION_FACTOR;

			//bobbing adjustments
			if(stunned)bobfactor*=4.;
			else if(cansprint && runwalksprint>0)bobfactor*=1.6;
			else if(runwalksprint<0||mustwalk){
				if(player.crouchfactor==1)bobfactor*=0.4;
				else bobfactor*=0.7;
			}

			if(!player.onground && !bNoGravity && !waterlevel){
				// [RH] allow very limited movement if not on ground.
				movefactor*=level.aircontrol;
				bobfactor*=level.aircontrol;
			}

			//"override double,double TweakSpeeds()"...
			double basespeed=speed*12.;
			if(cmd.forwardmove){
				fm=basespeed;
				if(cmd.forwardmove<0)fm*=-0.8;
			}
			if(cmd.sidemove>0)sm=basespeed;
			else if(cmd.sidemove<0)sm=-basespeed;
			if(!player.morphTics){
				double factor=1.;
				for(let it=Inv;it;it=it.Inv){
					factor *= it.GetSpeedFactor();
				}
				fm*=factor;
				sm*=factor;
			}

			// When crouching, speed <s>and bobbing</s> have to be reduced
			if(CanCrouch() && player.crouchfactor != 1 && runwalksprint>=0){
				fm *= player.crouchfactor;
				sm *= player.crouchfactor;
			}

			if(fm&&sm)movefactor*=HDCONST_ONEOVERSQRTTWO;

			forwardmove = fm * movefactor * (35 / TICRATE);
			sidemove = sm * movefactor * (35 / TICRATE);

			if(forwardmove){
				Bob(Angle, cmd.forwardmove * bobfactor / 256., true);
				ForwardThrust(forwardmove, Angle);
			}
			if(sidemove){
				let a = Angle - 90;
				Bob(a, cmd.sidemove * bobfactor / 256., false);
				Thrust(sidemove, a);
			}
			if(leanmove&&notpredicting){
				bool poscmd=leanmove>0;
				bool zrk=zerk>0;
				if(zrk&&!random(0,63)){
					JumpCheck(0,poscmd?1024:-1024,true);
					leaned=0;
				}else{
					let a = Angle - 90;
					leaned=clamp(poscmd?leaned+1:leaned-1,-8,8);
					if(zrk){
						leaned=clamp(poscmd?leaned+1:leaned-1,-8,8);
						leanamt*=2;
					}
					if(!poscmd)leanamt=-leanamt;
					if(abs(leaned)<8){
						TryMove(
							pos.xy+(cos(a),sin(a))*leanamt,
							false
						);
					}
				}
			}

			if(
				notpredicting
				&&(forwardmove||sidemove)
			){
				PlayRunning();
			}

			if(player.cheats & CF_REVERTPLEASE){
				player.cheats &= ~CF_REVERTPLEASE;
				player.camera = player.mo;
			}
		}

		//undo leaning
		if(notpredicting){
			if(!leanmove&&leaned){
				let a=angle+90;
				if(leaned>0)leaned--;
				else if(leaned<0){
					leaned++;
					leanamt=-leanamt;
				}
				TryMove(
					pos.xy+(cos(a),sin(a))*leanamt,
					false
				);
			}
			A_SetRoll((leaned>0?leaned:-leaned)*leanamt,SPF_INTERPOLATE);
		}
	}
	int leaned;
	int cmdleanmove;
}




//handler for receiving direct button lean input
extend class HDHandlers{
	void Lean(hdplayerpawn ppp,int dir){
		if(!ppp.player)return;
		int cmdleanmove=ppp.cmdleanmove;
		if(dir==999){
			cmdleanmove|=HDCMD_STRAFE;
		}else if(dir==99){
			cmdleanmove&=~HDCMD_RIGHT;
		}else if(dir==-99){
			cmdleanmove&=~HDCMD_LEFT;
		}else if(dir==1){
			cmdleanmove|=HDCMD_RIGHT;
		}else if(dir==-1){
			cmdleanmove|=HDCMD_LEFT;
		}else cmdleanmove=0;
		ppp.cmdleanmove=cmdleanmove;
	}
}
enum leanmovecmd{
	HDCMD_STRAFE=1,
	HDCMD_LEFT=2,
	HDCMD_RIGHT=4,
}


