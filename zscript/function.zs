// ------------------------------------------------------------
// Basic functional stuff
// ------------------------------------------------------------

//event handler
class HDHandlers:EventHandler{
	array<double> invposx;
	array<double> invposy;
	array<double> invposz;

	override void RenderOverlay(renderevent e){
		hdlivescounter.RenderEndgameText(e.camera);
	}
	override void WorldLoaded(WorldEvent e){
		//seed a few more spawnpoints
		for (int i=0;i<5;i++){
			vector3 ip=level.PickDeathmatchStart();
			invposx.push(ip.x);
			invposy.push(ip.y);
			invposz.push(ip.z);
		}

		if(hd_flagpole)spawnflagpole();

		//reset some player stuff
		for(int i=0;i<MAXPLAYERS;i++){
			flagcaps[i]=0;
		}

		//misc. map hacks
		textureid dirtyglass=texman.checkfortexture("WALL47_2",texman.type_any);
		int itmax=level.lines.size();
		for(int i=0;i<itmax;i++){
			line lll=level.lines[i];

			//no more killer elevators
			if(lll.special){
				switch(lll.special){

				//cap platform speeds
				case Plat_DownByValue:
				case Plat_DownWaitUpStayLip:
				case Plat_DownWaitUpStay:
				case Generic_Lift:
				case Plat_PerpetualRaiseLip:
				case Plat_PerpetualRaise:
				case Plat_RaiseAndStayTx0:
				case Plat_UpByValue:
				case Plat_UpByValueStayTx:
				case Plat_UpNearestWaitDownStay:
				case Plat_UpWaitDownStay:
					if(!hd_safelifts||abs(lll.args[1])>64)break;
					lll.args[1]=clamp(lll.args[1],-24,24);
					break;

				//prevent lights from going below 1
				case Light_ChangeToValue:
				case Light_Fade:
				case Light_LowerByValue:
					lll.args[1]=max(lll.args[1],1);break;
				case Light_Flicker:
				case Light_Glow:
				case Light_Strobe:
					lll.args[2]=max(lll.args[2],1);break;
				case Light_StrobeDoom:
					lll.args[2]=min(lll.args[2],1);break;
				case Light_RaiseByValue:
					if(lll.args[1]>=0)break;
				case Light_LowerByValue:
					sectortagiterator sss=level.createsectortagiterator(lll.args[0]);
					int ssss=sss.next();
					int lowestlight=255;
					while(ssss>-1){
						lowestlight=min(lowestlight,level.sectors[ssss].lightlevel);
						ssss=sss.next();
					}
					lll.args[1]=min(lll.args[1],lowestlight-1);

				default: break;
				}
			}
			//if block-all and no midtexture, force add a mostly transparent midtexture
			if(
				hd_dirtywindows
				&&lll.sidedef[1]
				&&(
					lll.flags&line.ML_BLOCKEVERYTHING
					||lll.flags&line.ML_BLOCKPROJECTILE
					||lll.flags&line.ML_BLOCKHITSCAN
//					||lll.flags&line.ML_BLOCKING
				)
				&&!lll.sidedef[0].gettexture(side.mid)
				&&!lll.sidedef[1].gettexture(side.mid)
			){
				lll.flags|=line.ML_WRAP_MIDTEX;
				lll.sidedef[0].settexture(side.mid,dirtyglass);
				lll.sidedef[1].settexture(side.mid,dirtyglass);
				lll.alpha=0.2;
			}
		}
	}
}

//because "extend class Actor" doesn't work
class HDActor:Actor{
	default{
		+noblockmonst
	}
	//advance to the next tic without doing anything
	//don't actually use this, it's just for reference
	void nexttic(){
		if(CheckNoDelay()){
			if(tics>0)tics--;  
			while(!tics){
				if(!SetState(CurState.NextState)){
					return;
				}
			}
		}
	}
	//decorate wrapper for HDMath.CheckLump()
	bool CheckLump(string lumpname){
		return HDMath.CheckLump(lumpname);
	}
	//"After that many drinks anyone would be blowing chunks all night!"
	//"Chunks is the name of my dog."
	//for frags: A_SpawnChunks("HDFrag",42,100,700);
	void A_SpawnChunks(
		class<actor> chunk,
		int number=12,
		double minvel=10,
		double maxvel=20
	){
		if(
			chunk is "WallChunk"
		){
			int ch=0;
			thinkeriterator chit=thinkeriterator.create(chunk,STAT_DEFAULT);
			while(chit.Next(exact:false))ch++;
			if(ch>500){  
				if(hd_debug)A_Log(string.format("%i is too many chunks, %s not spawned",ch,chunk.getclassname()));
				return;
			}
		}
		double burstz=pos.z+height*0.5;
		double minpch=burstz-floorz<56?9:90;
		double maxpch=ceilingz-burstz<56?-9:-90;
		burstz-=pos.z;
		for(int i=0;i<number;i++){
			bool gbg;actor frg;
			double pch=frandom(minpch,maxpch);
			double vl=frandom(minvel,maxvel);
			[gbg,frg]=A_SpawnItemEx(
				chunk,
				0,0,burstz,
				vl*cos(pch),0,vl*sin(-pch),
				frandom(0,360),
				SXF_NOCHECKPOSITION|SXF_TRANSFERPITCH|SXF_TRANSFERPOINTERS
			);
			frg.vel+=vel;
			frg.bseeinvisible=true; //work around hack that normally lets HDBullet out
		}
	}
	//roughly equivalent to CacoZapper
	static void ArcZap(actor caller){
		caller.A_CustomRailgun((random(4,8)),frandom(-12,12),"","azure",
			RGF_SILENT|RGF_FULLBRIGHT,
			1,4000,"HDArcPuff",180,180,frandom(32,128),4,0.4,0.6
		);
	}
}
class HDArcPuff:HDActor{
	default{
		+nogravity
		+puffgetsowner
		+puffonactors
		+forcepain
		+noblood
		scale 0.4;
		damagetype "Electro";
		radius 0.1;
		height 0.1;
	}
	states{
	spawn:
		TNT1 A 5 A_PlaySound("misc/arczap",0,0.1,0,0.4);
		stop;
	}
}

class InventoryFlag:Inventory{
	default{
		+inventory.untossable;+nointeraction;+noblockmap;
		inventory.maxamount 1;inventory.amount 1;
	}
	states{
	spawn:
		TNT1 A 0;
		stop;
	}
}
class ActionItem:CustomInventory{
	default{
		+inventory.untossable -inventory.invbar +noblockmap
	}
	//wrapper for HDWeapon and ActionItem
	//remember: LEFT and DOWN
	//would use vector2s but lol bracketing errors I don't need that kind of negativity in my life
	action void A_MuzzleClimb(
		double mc10=0,double mc11=0,
		double mc20=0,double mc21=0,
		double mc30=0,double mc31=0,
		double mc40=0,double mc41=0
	){
		let hdp=HDPlayerPawn(self);
		if(hdp){
			hdp.A_MuzzleClimb((mc10,mc11),(mc20,mc21),(mc30,mc31),(mc40,mc41));
		}else{ //I don't even know why
			vector2 mc0=(mc10,mc11)+(mc20,mc21)+(mc30,mc31)+(mc40,mc41);
			A_SetPitch(pitch+mc0.y,SPF_INTERPOLATE);
			A_SetAngle(angle+mc0.x,SPF_INTERPOLATE);
		}
	}
	states{
	nope:
		TNT1 A 0;fail;
	spawn:
		TNT1 A 0;stop;
	}
}
class IdleDummy:HDActor{
	default{
		+noclip +nointeraction +noblockmap
		height 0;radius 0;
	}
	states{
	spawn:
		TNT1 A -1 nodelay{
			if(stamina>0)A_SetTics(stamina);  
		}stop;
	}
}
class CheckPuff:IdleDummy{
	default{
		+bloodlessimpact +hittracer +puffonactors +alwayspuff +puffgetsowner
		stamina 1;
	}
}
//mostly for doing TryMove checks to grab blockingline data
class TMChecker:HDActor{
	default{
		radius 3;height 1;maxstepheight 0;
	}
	states{
	spawn:
		TNT1 A 1;
		stop;
	}
}


// Blocker to prevent shotguns from overpenetrating multiple targets
// tempshield.spawnshield(self);
class tempshield:HDActor{
	default{
		-solid +shootable +nodamage
		radius 16;height 50;
		stamina 16;
	}
	static actor spawnshield(
		actor caller,class<actor> type="tempshield",
		bool deathheight=false,int shieldlength=16
	){
		actor sss=caller.spawn(type,caller.pos,ALLOW_REPLACE);
		if(!sss)return null;
		sss.master=caller;
		sss.A_SetSize(
			caller.radius,
			deathheight?getdefaultbytype(caller.getclass()).deathheight
			:getdefaultbytype(caller.getclass()).height
		);
		sss.bnoblood=caller.bnoblood;
		sss.stamina=shieldlength;
		return sss;
	}
	states{
	spawn:
		TNT1 A 1 nodelay{
			if(!master||stamina<1){destroy();return;}
			setorigin(master.pos,false);
			stamina--;
		}wait;
	}
}
class tempshield2:tempshield{
	default{
		radius 18;height 26;
		stamina 10;
	}
}
class tempshieldyellow:tempshield{
	default{bloodcolor "aa 99 22";}
}
class tempshieldgreen:tempshield{
	default{bloodcolor "44 99 22";}
}
class tempshield2green:tempshield2{
	default{bloodcolor "44 99 22";}
}
class tempshieldblue:tempshield{
	default{bloodcolor "00 00 99";}
}
class tempshield2blue:tempshield2{
	default{bloodcolor "00 00 99";}
}
class tempshieldpuff:tempshield{
	default{+noblood}
}
class tempshield2puff:tempshield2{
	default{+noblood}
}


//collection of generic math functions
struct HDMath{
	//return true if lump exists
	//mostly for seeing if we're playing D1 or D2
	//HDMath.CheckLump("SHT2A0")
	static bool CheckLump(string lumpname){
		return Wads.CheckNumForName(lumpname,wads.ns_sprites,-1,false)>=0;
	}
	//return the maximum capacity for this actor and this inventory
	//HDMath.MaxInv(self,"FourMilAmmo")
	static int MaxInv(actor holder,class<inventory> inv){
		if(holder.findinventory(inv))return holder.findinventory(inv).maxamount;
		else if((class<hdpickup>)(inv)){
			double gdpsp;
			if(hdplayerpawn(holder))gdpsp=hdplayerpawn(holder).maxpocketspace;
			else gdpsp=getdefaultbytype("hdplayerpawn").maxpocketspace;
			let mag=(class<hdmagammo>)(inv);
			if(mag){
				let minvv=getdefaultbytype((class<hdmagammo>)(inv));
				double unitbulk=(minvv.roundbulk*minvv.maxperunit*0.6)+minvv.magbulk;
				return unitbulk?max(1,gdpsp/unitbulk):int.MAX;
			}else{
				let invv=getdefaultbytype((class<hdpickup>)(inv));
				double bulk=invv.bulk;
				return bulk?max(1,gdpsp/bulk):int.MAX;
			}
		}
		return getdefaultbytype(inv).maxamount;
	}
	//checks encumbrance multiplier
	//hdmath.getencumbrancemult()
	static double GetEncumbranceMult(){
		if(deathmatch||skill>=5)return clamp(hd_encumbrance,1.,2.);
		return clamp(hd_encumbrance,0.,2.);
	}
	//counts stuff
	//HDMath.CountThinkers("IdleDummy")
	static int Count(name type,bool exactmatch=false){
		int count=0;
		thinkeriterator it=thinkeriterator.create(type);
		while(it.Next(exact:exactmatch))count++;
		return count;
	}
	//get the opposite sector of a line
	static sector OppositeSector(line hitline,sector hitsector){
		if(!hitline||!hitline.backsector)return null;
		if(hitline.backsector==hitsector)return hitline.frontsector;
		return hitline.backsector;
	}
	//calculate the speed at which 2 actors are moving towards each other
	static double TowardsEachOther(actor a1, actor a2){
		vector3 oldpos1=a1.pos;
		vector3 oldpos2=a2.pos;
		vector3 newpos1=oldpos1+a1.vel;
		vector3 newpos2=oldpos2+a2.vel;
		double l1=(oldpos1-oldpos2).length();
		double l2=(newpos1-newpos2).length();
		return l1-l2;
	}
	//kind of like angleto
	static double pitchto(vector3 this,vector3 that){
		return atan2(this.z-that.z,(this.xy-that.xy).length());
	}
	//return a string indicating a rough cardinal direction
	static string CardinalDirection(int angle){
		angle%=360;
		if(angle<0)angle+=360;
		if(angle>=22&&angle<=66)return("northeast");
		else if(angle>=67&&angle<=113)return("north");
		else if(angle>=114&&angle<=158)return("northwest");
		else if(angle>=159&&angle<=203)return("west");
		else if(angle>=204&&angle<=248)return("southwest");
		else if(angle>=249&&angle<=292)return("south");
		else if(angle>=293&&angle<=338)return("southeast");
		return("east");
	}
	//return a loadout and its name, icon and description, e.g. "Robber: pis, bak~Just grab and run."
	static string,string,string,string GetLoadoutStrings(string input,bool keepspaces=false){
		int pnd=input.indexof("#");
		int col=input.indexof(":");
		int sls=input.indexof("/");

		//"STFEVL0#Voorhees:saw/Chainsaw: Your #1 communicator!"
		if(sls>0){
			if(sls<pnd)pnd=-1;
			if(sls<col)col=-1;
		}

		string pic;if(pnd<0)pic="";else pic=input.left(pnd);
		string nam;if(col<0)nam="";else nam=input.left(col);
		string desc;if(sls<0)desc="";else desc=input.mid(sls+1);
		if(nam!="")pic.replace(nam,"");	//delete these !="" checks later, it's a GZ bug that's been fixed
		pic.replace("#","");
		pic.replace(":","");
		if(pic!="")nam.replace(pic,"");
		nam.replace("#","");
		nam.replace(":","");
		desc.replace("/","");

		string lod=input;
		if(pic!="")lod.replace(pic,"");
		if(nam!="")lod.replace(nam,"");
		if(desc!="")lod.replace(desc,"");
		lod.replace("#","");
		lod.replace(":","");
		lod.replace("/","");
		if(!keepspaces)lod.replace(" ","");
		lod=lod.makelower();

		if(hd_debug>1)console.printf(
			pic.."   "..
			nam.."   "..
			lod.."   "..
			desc
		);
		return lod,nam,pic,desc;
	}
}
struct HDF play{
	//because this is 10 times faster than A_GiveInventory
	static void Give(actor whom,class<inventory> what,int howmany=1){
		whom.A_SetInventory(what,whom.countinv(what)+howmany);
	}
	//transfer fire. returns # of fire actors affected.
	static int TransferFire(actor ror,actor ree,int maxfires=-1){
		actoriterator it=level.createactoriterator(-7677,"HDFire");
		actor fff;int counter;
		bool eee;if(ree)eee=true;
		while(maxfires && (fff=it.next())){
			maxfires--;
			if(fff.target==ror){
				counter+=fff.stamina;
				if(eee)fff.target=ree;
				else fff.destroy();
			}
		}
		return counter;
	}
	//split inventory item to match pickup sprite
	static void SplitAmmoSpawn(inventory caller,int maxunit=1){
		while(caller.amount>maxunit){
			caller.amount-=maxunit;
			inventory bbb=inventory(caller.spawn(caller.getclass(),caller.pos,ALLOW_REPLACE));
			bbb.amount=maxunit;bbb.vel=caller.vel+(frandom(-1,1),frandom(-1,1),frandom(-1,1));
		}
	}
	//figure out if something hit some map geometry that isn't (i.e., "sky").
	//why is GetTexture play!?
	static bool linetracehitsky(flinetracedata llt){
		if(
			(
				llt.hittype==Trace_HitCeiling
				&&llt.hitsector.gettexture(1)==skyflatnum
			)||(
				llt.hittype==Trace_HitFloor
				&&llt.hitsector.gettexture(0)==skyflatnum
			)||(
				!!llt.hitline
				&&llt.hitline.special==Line_Horizon
			)
		)return true;
		let othersector=hdmath.oppositesector(llt.hitline,llt.hitsector);
		if(!othersector)return false;
		return(
			llt.hittype==Trace_HitWall
			&&(
				(
					othersector.gettexture(othersector.ceiling)==skyflatnum
					&&othersector.ceilingplane.zatpoint(llt.hitdir.xy)<llt.hitlocation.z
				)||(
					othersector.gettexture(othersector.floor)==skyflatnum
					&&othersector.floorplane.zatpoint(llt.hitdir.xy)>llt.hitlocation.z
				)
			)
		);
	}
	//process shields
	//[shields,damage]=hdf.gothroughshields(shields,damage,inflictor,mod,flags);
	static int,int GoThroughShields(int shields,int damage,actor inflictor=null,name mod="none",int flags=0){
		if(
			shields<1
			||!(flags&DMG_NO_FACTOR)
			||flags&DMG_FORCED
			||mod=="internal"
			||mod=="falling"
		)return shields,damage;

		int blocked=min(shields,damage,100);
		if(blocked==damage&&!random(0,3))blocked--;
		damage-=blocked;

		shields=clamp(shields-(mod=="BFGBallAttack"?blocked*100:blocked-20),0,shields);

		if(inflictor&&!inflictor.bismonster&&!inflictor.player){
			int shrd=max(random(0,1),damage/50);
			for(int i=0;i<shrd;i++){
				actor aaa=inflictor.spawn("FragShard",inflictor.pos,ALLOW_REPLACE);
				aaa.vel=(frandom(-3,3),frandom(-3,3),frandom(-3,3));
			}
		}
		return shields,damage;
	}
}






//debug thingy
class HDRaiseWep:HDWeapon{
	default{
		-weapon.no_auto_switch
		+weapon.cheatnotweapon
		weapon.slotnumber 0;
	}
	states{
	ready:
		TNT1 A 1 A_WeaponReady();
		goto readyend;
	fire:
		TNT1 A 0{
			flinetracedata rlt;
			LineTrace(
				angle,128,pitch,
				TRF_ALLACTORS,
				offsetz:height-6,
				data:rlt
			);
			if(rlt.hitactor){
				a_weaponmessage(rlt.hitactor.getclassname().." raised!",30);
				RaiseActor(rlt.hitactor,RF_NOCHECKPOSITION);
			}else a_weaponmessage("click on something\nto raise it.",25);
		}goto nope;
	}
}
class HDRaise:CustomInventory{
	states{
	spawn:TNT1 A 0;stop;
	pickup:
		TNT1 A 0{
			flinetracedata rlt;
			LineTrace(
				angle,128,pitch,
				TRF_ALLACTORS,
				offsetz:height-6,
				data:rlt
			);
			if(rlt.hitactor){
				a_log(rlt.hitactor.getclassname().." raised!");
				RaiseActor(rlt.hitactor,RF_NOCHECKPOSITION);
			}else a_log("point at something\nto raise it.",true);
		}fail;
	}
}


