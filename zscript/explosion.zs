// ------------------------------------------------------------
// Radius damage effect combos!
// ------------------------------------------------------------

//need to do a new explosion to immolate things properly
//...can we do a combo exploder (blast, frags and immolate)?
extend class HDActor{
	void A_HDBlast(
		double blastradius=0,int blastdamage=0,double fullblastradius=0,name blastdamagetype="None",
		double pushradius=0,double pushamount=0,double fullpushradius=0,bool pushmass=true,
		double fragradius=0,int fragdamage=0,name fragdamagetype="SmallArms1",
		double immolateradius=0,int immolateamount=1,int immolatechance=100,
		double gibradius=0,int gibamount=1,
		bool hurtspecies=true,
		actor source=null,
		bool passwalls=false
	){
		hdactor.HDBlast(self,
			blastradius,blastdamage,fullblastradius,blastdamagetype,
			pushradius,pushamount,fullpushradius,pushmass,
			fragradius,fragdamage,fragdamagetype,
			immolateradius,immolateamount,immolatechance,
			gibradius,gibamount,
			hurtspecies,
			source,
			passwalls
		);
	}
	static void HDBlast(actor caller,
		double blastradius=0,int blastdamage=0,double fullblastradius=0,name blastdamagetype="None",
		double pushradius=0,double pushamount=0,double fullpushradius=0,bool pushmass=true,
		double fragradius=0,int fragdamage=0,name fragdamagetype="SmallArms1",
		double immolateradius=0,int immolateamount=1,int immolatechance=100,
		double gibradius=0,int gibamount=1,
		bool hurtspecies=true,
		actor source=null,
		bool passwalls=false
	){
		//get the biggest radius
		int bigradius=max(
			blastradius,
			fragradius,
			immolateradius,
			gibradius
		);

		//initialize things to be used in the iterator
		if(!source){
			if(caller.target)source=caller.target;
			else if(caller.master)source=caller.master;
			else source=caller;
		}
		actor target=caller.target;

		//do all this from the centre
		double callerhalfheight=caller.height*0.5;
		caller.addz(callerhalfheight);

		blockthingsiterator itt=blockthingsiterator.create(caller,bigradius);
		while(itt.Next()){
			actor it=itt.thing;
			double losmul=0;

			if(	//abort all checks if no hurt species
				!it
				||it==caller
				||(
					!hurtspecies
					&&it.species==source.species
					&&!it.ishostile(source)
				)
			)continue;

			double ithalfheight=it.height*0.5;
			it.addz(ithalfheight); //get the middle not the bottom
			double dist=caller.distance3d(it);
			double dist2=caller.distance2d(it);
			it.addz(-ithalfheight); //reset "it"'s position

			bool ontop=
				(!dist || dist<min(it.radius,ithalfheight))?true
				:false;
			double divdist=ontop?1:clamp(1./dist,0.,1.);

			int playerattack=0;//source&&source.player?DMG_PLAYERATTACK:0;

			//check LOS
			if(passwalls)losmul=1.;
			else{
				double biggerradius=bigradius+it.radius;
				double smallerradius=it.radius-1;
				flinetracedata blt;
				double difz=it.pos.z-caller.pos.z;
				double pitchtotop=-atan2(difz+it.height,dist2);
				double pitchtomid=-atan2(difz+ithalfheight,dist2);
				double pitchtobottom=-atan2(difz,dist2);
				double angletomid=caller.angleto(it);

				caller.linetrace(angletomid,biggerradius,pitchtotop,0,
					0, //caller is already raised by half its height for other things
					data:blt
				);
				if(blt.hitactor==it)losmul+=0.25;
				caller.linetrace(angletomid,biggerradius,pitchtomid,0,
					0, //caller is already raised by half its height for other things
					data:blt
				);
				if(blt.hitactor==it)losmul+=0.25;

				double edgeshot=atan2(smallerradius,dist);
				caller.linetrace(angletomid+edgeshot,biggerradius,pitchtomid,0,
					0, //caller is already raised by half its height for other things
					data:blt
				);
				if(blt.hitactor==it)losmul+=0.17;
				caller.linetrace(angletomid-edgeshot,biggerradius,pitchtomid,0,
					0, //caller is already raised by half its height for other things
					data:blt
				);
				if(blt.hitactor==it)losmul+=0.17;

				caller.linetrace(angletomid,biggerradius,pitchtobottom,0,
					0, //caller is already raised by half its height for other things
					data:blt
				);
				if(blt.hitactor==it)losmul+=0.16;
				losmul=min(losmul,1.);
			}
//				if(losmul){caller.A_Log(string.format("%s  %f",it.getclassname(),losmul));}

			if(!losmul)continue;
			double divmass=1.;if(it.mass>0)divmass=1./it.mass;

			//immolate before all damage, to avoid bypassing player death transfer
			if(!it)continue;if(dist<=immolateradius){
				if(immolateamount<0){
					HDF.Give(it,"Heat",-immolateamount+random(-immolatechance,immolatechance));
				}else if(!it.countinv("ImmunityToFire")&&immolatechance>=random(1,100)*losmul){
					if(hdactor(caller))hdactor(caller).A_Immolate(it,target,immolateamount);
					else HDF.Give(it,"Heat",immolateamount*2);
				}
			}
			//gibbing
			if(!it)continue;if(dist<=gibradius && it.bcorpse && it.bshootable){
				hdf.give(it,"sawgib",gibamount-dist/3);
				actor bld;bool gbg;
				double minbloodheight=min(4.,it.height*0.2);
				for(int i=0;i<gibamount;i+=3){
					[gbg,bld]=it.A_SpawnItemEx(it.bloodtype,
						it.radius*frandom(0.6,1),
						frandom(-it.radius,it.radius)*0.5,
						frandom(minbloodheight,it.height),
						frandom(-1,4),
						frandom(-4,4),
						frandom(1,7),
						it.angleto(caller),
						SXF_ABSOLUTEANGLE|SXF_NOCHECKPOSITION|SXF_USEBLOODCOLOR
					);
					bld.vel+=it.vel;
				}
				if(!it.bdontthrust)it.vel+=(it.pos-caller.pos)*divdist*divmass*10;
			}
			//push
			if(!it)continue;if(dist<=pushradius && it.bshootable && !it.bdontthrust){
				if(it.radiusdamagefactor)pushamount*=it.radiusdamagefactor;
				vector3 push=(it.pos-caller.pos)*divdist
					*clamp(pushamount-clamp(dist-fullpushradius,0,dist),0,pushamount);
				if(pushmass){
					if(pushamount<=it.mass)push=(0,0,0);
					else{
						push*=divmass;
						if(push.z>0)push-=(0,0,caller.mass*it.gravity);
					}
				}
				it.vel+=push;
			}
			//blast damage
			if(!it)continue;if(dist<=blastradius && (it.bshootable||it.bvulnerable)){
				if(it.radiusdamagefactor)blastdamage*=it.radiusdamagefactor;
				int dmg=(dist>fullblastradius)?
					blastdamage-clamp(dist-fullblastradius,0,dist)
					:blastdamage;
				it.DamageMobj(caller,source,dmg*losmul,blastdamagetype,DMG_THRUSTLESS|playerattack);
			}
			//frag damage
			if(!it)continue;if(
				dist<=fragradius
				&&(it.bsolid || it.bshootable || it.bvulnerable)
			){
				if(it.radiusdamagefactor)fragdamage*=it.radiusdamagefactor;
				caller.A_Face(it);
				if(
					(
						it.bvulnerable||(
							it.bshootable
							&&it.radius
							&&it.height
						)
					)
				){
					//determine size of arc exposed to frags
					//ideally it would be the arc from corner to corner
					//but this will do for now
					double angcover=atan2(
						it.height,//(it.radius*2+it.height)*0.5,
						dist
					);
//caller.A_Log(string.format("%s  %f",it.getclassname(),angcover));
					int fragshit=5000;
					if(dist>0){
						//HIGH SCHOOL GEOMETRY
						//https://en.wikipedia.org/wiki/Spherical_sector
						double domeheight=abs(sin(90-0.5*angcover));
						double domearea=HDCONST_TAU*domeheight; //*dist
						double blastarea=(HDCONST_TAU*2)*dist; //*dist
						double proportionfragged=domearea/blastarea;

						//NOW incorporate the cover
						proportionfragged*=losmul;

						//2500 frags = 2-45 frags on any given target
						fragshit*=proportionfragged;
					}

//caller.A_Log(string.format("%s  %i",it.getclassname(),fragshit));

					//randomize count and abort if none end up hitting
					fragshit*=frandom(0.9,1.1);
					if(fragshit<1)continue;

					//base damage
					int dmg=min(fragshit*max(fragdamage>>4-random(0,it.countinv("BulletResistance")),1),fragdamage);
					//crits
					if(frandom(0,1)<(0.01*fragshit))dmg*=frandom(1.,2.);

					//SO MUCH BLOOD
					if(
						!(it is "TempShield")
					){
						caller.A_Face(it,0,0);
						name bld="FragPuff";
						if(!it.bnoblood&&it.bloodtype)bld=it.bloodtype;
						int gbg;actor blaaa;vector2 blooddir=(caller.pos.xy-it.pos.xy).unit();
						if(blooddir.x!=blooddir.x)blooddir.x=frandom(3,3);
						if(blooddir.y!=blooddir.y)blooddir.y=frandom(3,3);
						int bloodshit=min(fragshit,it.height*0.5);
						for(int i=0;i<bloodshit;i++){
							[gbg,blaaa]=it.A_SpawnItemEx(bld,
								frandom(-1,it.radius),
								frandom(-it.radius,it.radius)*0.6,
								frandom(4,it.height),
								blooddir.x*frandom(-1,4),
								blooddir.y*frandom(-4,4),
								frandom(-1,3),
								-caller.angle,
								SXF_USEBLOODCOLOR
								|SXF_ABSOLUTEANGLE
								|SXF_ABSOLUTEMOMENTUM
								|SXF_NOCHECKPOSITION
							);
							blaaa.vel+=it.vel;
						}
					}

					//limit damage to non-gibbing levels
					//can still gib, just takes a lot more
					int itgibhealth=it.gibhealth;
					int ithealth=it.health;
					if(
						ithealth>0&&
						itgibhealth>0
					){
						int gh=ithealth+itgibhealth;
						if(dmg>gh){
							dmg=min(gh,gh-itgibhealth*3);
							if(dmg<1)dmg=ithealth+1;
						}
					}


					//and finally the good stuff
					if(hd_debug)caller.A_Log(
						string.format("%s fragged %i times by %s for %i damage",
							it.getclassname(),fragshit,caller.getclassname(),dmg
						)
					);
					int pcbak=it.painchance;
					it.painchance*=fragshit;
					it.DamageMobj(caller,source,dmg,fragdamagetype,DMG_THRUSTLESS|playerattack);
					if(it)it.painchance=pcbak;
				}
			}
		}
		//reset position
		if(caller)caller.addz(-callerhalfheight);
	}
}
