//-------------------------------------------------
// Ladder
//-------------------------------------------------

//show where the ladder is hanging
//no it doesn't swing, math is hard :(
class hdladdersection:IdleDummy{
	int secnum;
	default{
		+wallsprite
	}
	states{
	spawn:
		LADD B 0 nodelay A_JumpIf(master&&target,1);
		stop;
		LADD B 1 setz(max(target.floorz,master.pos.z-LADDER_SECTIONLENGTH*secnum));
		loop;
	}
}
class hdladdertop:hdactor{
	default{
		//$Category "Misc/Hideous Destructor/"
		//$Title "Ladder Top"
		//$Sprite "LADDA0"

		+missile //testing
		+flatsprite
		+nointeraction
		height 1;radius 10;
		mass int.MAX;
	}
	states{
	spawn:
		LADD A 1 nodelay{setz(getzat()+4);}
		wait;
	}
	override void postbeginplay(){
		super.postbeginplay();
		pitch=18;
		bmissile=false;master=target;
		setz(floorz);
		fcheckposition tm;
		vector2 mvlast=pos.xy;
		vector2 mv=angletovector(angle,2);
		for(int i=0;i<20;i++){

			mvlast+=mv;
			checkmove(mvlast,PCM_DROPOFF|PCM_NOACTORS,tm);

			//found a place for the ladder to hang down
			int htdiff=clamp(floorz-tm.floorz,0,LADDER_MAX);
			if(
				htdiff
			){

				//spawn the ladder end
				target=spawn("hdladderbottom",tm.pos,ALLOW_REPLACE);
				target.target=self;
				target.master=master;
				target.angle=angle;
				target.pitch=-27;

				vector2 mv2=mv*0.02;
				vector3 newpos=tm.pos;

				//spawn the ladder sections
				double sectionlength=min(htdiff,LADDER_MAX)/LADDER_SECTIONS;
				for(int i=1;i<=LADDER_SECTIONS;i++){
					newpos.xy+=mv2;
					let sss=hdladdersection(spawn("hdladdersection",newpos,ALLOW_REPLACE));
					sss.master=self;sss.target=target;sss.angle=angle+frandom(-1.,1.);
					sss.secnum=i;
					target.setorigin(newpos+(0,0,-sectionlength*i),true);
					if(master){
						sss.translation=master.translation;
						target.translation=master.translation;
					}
				}

				//reposition the thing
				setorigin((tm.pos.xy-mv*radius,floorz),true);

				//only complete if start or within throwable range, else abort
				if(!master)return;
				A_PlaySound("misc/ladder");
				if(pos.z-master.pos.z<108){
					master.A_Log(string.format("You hang up a ladder.%s",master.getcvar("hd_helptext")?" Use the ladder to climb.":""),true);
					master.A_TakeInventory("PortableLadder",1);
					return;
				}
			}
		}

		//if there's no lower floor to drop the ladder, abort.
		if(master){
			master.A_Log("Can't hang a ladder here.",true);
		}else{
			actor hdl=spawn("PortableLadder",pos,ALLOW_REPLACE);
			hdl.A_PlaySound("misc/ladder");
		}
		destroy();
	}
}
const LADDER_MAX=800.;
const LADDER_SECTIONLENGTH=12.;
const LADDER_SECTIONS=LADDER_MAX/LADDER_SECTIONLENGTH;


class hdladderbottom:hdactor{
	default{
		+nogravity +flatsprite
		height 56;radius 10;
		mass int.MAX;
	}
	actor currentuser;
	double currentuserz;
	override bool used(actor user){
		double upz=user.pos.z;
		if(
			upz>target.pos.z+24  
			||upz+user.height*1.3<pos.z
		)return false;
		if(currentuser){
			disengageladder();
			return false;
		}
		currentuser=user;
		currentuser.vel.z+=1;
		currentuserz=user.pos.z;
		currentuser.A_Log(string.format("You climb the ladder.%s",user.getcvar("hd_helptext")?" Use again or jump to disengage; crouch and jump to pull down the ladder with you.":""),true);
		return true;
	}
	void disengageladder(bool message=true){
		if(!currentuser)return;
		if(playerpawn(currentuser))playerpawn(currentuser).viewbob=1.;
		if(message)currentuser.A_Log("Ladder disengaged.",true);
		currentuser=null;
	}
	override void ondestroy(){
		if(playerpawn(currentuser))playerpawn(currentuser).viewbob=1.;
		super.ondestroy();
	}
	override void tick(){
		if(!target){destroy();return;}
		setz(
			clamp(pos.z,
				max(target.pos.z-LADDER_MAX,floorz),
				target.pos.z+LADDER_MAX
			)
		);

		if(currentuser){
			if(currentuser.health<1){disengageladder(false);return;}


			//check if facing the ladder
			bool facing=abs(
				deltaangle(
					currentuser.angleto(self,true),
					currentuser.angle
				)
			)<90;

			//checks when above ladder
			if(
				currentuser.pos.z>target.pos.z-16
			){
				//throw in some use of controls still
				if(currentuser.player){
					int bt=currentuser.player.cmd.buttons;
					if(
						bt&BT_JUMP
						||bt&BT_SPEED
						||(!facing&&bt&BT_USE)
					){
						if(
							bt&BT_JUMP
							&&currentuser.height<
							getdefaultbytype(currentuser.getclass()).height
						){
							currentuser.A_Log("Ladder taken up.",true);
							actor hdl=spawn("PortableLadder",target.pos,ALLOW_REPLACE);
							hdl.A_PlaySound("misc/ladder");
							hdl.translation=translation;
							target.destroy();
							if(self)destroy();
						}else disengageladder();
						return;
					}
					if(currentuser.floorz<currentuser.pos.z){
						double fm=currentuser.player.cmd.forwardmove*0.000125;
						double sm=currentuser.player.cmd.sidemove*0.000125;
						if(fm||sm)currentuser.trymove(
							currentuser.pos.xy
							+angletovector(currentuser.angle,fm)
							+angletovector(currentuser.angle-90,sm),
							true
						);
					}
				}
				if(target.distance2d(currentuser)>40){  
					vector2 tp=pos.xy;
					currentuser.setorigin((
						clamp(currentuser.pos.x,
							tp.x-40,
							tp.x+40
						),
						clamp(currentuser.pos.y,
							tp.y-40,
							tp.y+40
						),
						min(currentuser.pos.z,target.pos.z+24)
					),true);
				}
				return;
			}
			if(distance2d(currentuser)<3.)currentuser.A_ChangeVelocity(-1,0,0,CVF_RELATIVE);
			currentuser.vel.xy*=0.7;
			currentuser.vel.z=0;

			//climbing interface
			if(currentuser.player){
				double spm=currentuser.speed;
				double fm=currentuser.player.cmd.forwardmove;
				if(fm>0)fm=spm;else if(fm<0)fm=-spm;else fm=0;
				double sm=currentuser.player.cmd.sidemove;
				if(sm>0)sm=spm;else if(sm<0)sm=-spm;else sm=0;

				int bt=currentuser.player.cmd.buttons;

				//barehanded and descending are faster
				if(facing){
					if(!sm&&fm<0)fm*=1.5;
					weapon wp=currentuser.player.readyweapon;
					if(wp is "HDFist"||wp is "NullWeapon"){
						sm*=2;fm*=2;
					}
				}else fm*=-1;

				if(currentuser.countinv("PowerStrength"))fm*=1.8;
				if(hdplayerpawn(currentuser)&&hdplayerpawn(currentuser).stunned)
					fm*=0.2;

				//apply climbing
				currentuserz=currentuser.pos.z+fm;
				if(sm)currentuser.trymove(
					currentuser.pos.xy+angletovector(currentuser.angle-90,sm),
					true
				);
				if(fm||sm)playerpawn(currentuser).viewbob=1;
					else playerpawn(currentuser).viewbob=0.;

				//jump also disengages
				//crouch+jump to remove the rope
				if(bt){
					if(bt&BT_JUMP){
						vector3 vl=(
							(currentuser.pos.xy-pos.xy).unit()*3,
							4
						);
						if(currentuser.countinv("PowerStrength"))vl*=2.2;
						currentuser.vel+=vl;

						if(
							currentuser.height<
							getdefaultbytype(currentuser.getclass()).height
						){
							currentuser.A_Log("Ladder taken down.",true);

							actor hdl=spawn("PortableLadder",target.pos,ALLOW_REPLACE);
							hdl.A_PlaySound("misc/ladder");
							hdl.vel.xy=vl.xy*2;
							hdl.translation=translation;

							GrabThinker.Grab(currentuser,hdl);

							target.destroy();
							if(self)destroy();
							return;
						}else disengageladder();
					}else if(!facing&&bt&BT_USE)disengageladder();
				}
			}
			if(!currentuser)return;

			currentuserz=max(currentuserz,pos.z-currentuser.height*1.3);
			currentuserz=min(currentuserz,currentuser.ceilingz-currentuser.height);
			currentuser.setorigin((
				clamp(currentuser.pos.x,
					pos.x-16,
					pos.x+16
				),
				clamp(currentuser.pos.y,
					pos.y-16,
					pos.y+16
				),
				currentuserz
			),true);
		}
		//nexttic
		if(CheckNoDelay()){
			if(tics>0)tics--;  
			while(!tics){
				if(!SetState(CurState.NextState)){
					return;
				}
			}
		}
	}
	states{
	spawn:
		LADD C -1;wait;
	}
}
class PortableLadder:HDPickup{
	default{
		inventory.icon "LADDD0";
		inventory.pickupmessage "Picked up a ladder.";
		height 20;radius 8;
		hdpickup.bulk ENC_LADDER;
		hdpickup.refid HDLD_LADDER;
		hdpickup.nicename "Ladder";
	}
	states{
	spawn:
		LADD D -1;
		stop;
	use:
		TNT1 A 0{
			actor aaa;int bbb;
			[bbb,aaa]=A_SpawnItemEx(
				"HDLadderTop",16*cos(pitch),0,48-16*sin(pitch),
				flags:SXF_NOCHECKPOSITION|SXF_SETTARGET
			);if(!aaa)return;

			//only face player if above player's height - otherwise why not just mantle?
			if(aaa.floorz>pos.z+height){  
				aaa.angle+=180;
			}
		}fail;
	}
}



