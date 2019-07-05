// ------------------------------------------------------------
// Because HD weapons aren't complicated enough.
// ------------------------------------------------------------
extend class HDStatusBar{
	virtual void drawweaponstatus(weapon w){
		let hdw=hdweapon(w);
		if(hdw)hdw.DrawHUDStuff(self,hdw,hpl);else{
			if(cplayer.readyweapon.ammotype1)drawwepnum(
				hpl.countinv(cplayer.readyweapon.ammotype1),
				hdmath.maxinv(hpl,cplayer.readyweapon.ammotype1)
			);
			if(cplayer.readyweapon.ammotype2)drawwepnum(
				hpl.countinv(cplayer.readyweapon.ammotype2),
				hdmath.maxinv(hpl,cplayer.readyweapon.ammotype2),
				posy:-10
			);
		}
	}
	void drawwepdot(int posx,int posy,vector2 dotscale=(3.,3.)){
		drawimage(
			"GREENPXL",(posx,posy),
			DI_SCREEN_CENTER_BOTTOM|DI_TRANSLATABLE|DI_ITEM_RIGHT,
			1,scale:dotscale
		);
	}
	void drawwepnum(int value,int maxvalue,int posx=-16,int posy=-6,bool alwaysprecise=false){
		if(!maxvalue)return;
		hdplayerpawn cp=hdplayerpawn(cplayer.mo);if(!cp)return;
		drawimage(
			"GREENPXL",
			(posx,posy),
			DI_SCREEN_CENTER_BOTTOM|DI_TRANSLATABLE|DI_ITEM_RIGHT,
			1,scale:(
				!alwaysprecise&&(
					hudlevel==1
					||cplayer.buttons&BT_ATTACK
					||cplayer.buttons&BT_ALTATTACK
				)
				?max(((value*6/maxvalue)<<2),(value>0)):
				(value*24/maxvalue)
			,2)
		);
	}
	//"" means ignore this value and move on to the next check.
	//"blank" means stop here and render nothing.
	//(do we really need 6???)
	void drawwepcounter(
		int input,
		int posx,int posy,
		string zero="",string one="",string two="",string three="",
		string four="",string five="",string six="",
		bool binary=false
	){
		string types[7];types[0]=zero;types[1]=one;types[2]=two;
		types[3]=three;types[4]=four;types[5]=five;types[6]=six;
		input=min(input,6);
		string result="";
		for(int i=input;i>=0;i--){
			if(input==i){
				if(types[i]=="blank")break;
				else if(types[i]=="")input--;
				else result=types[i];
			}
		}
		if(result!="")drawimage(
			result,
			(posx,posy),
			DI_SCREEN_CENTER_BOTTOM|DI_TRANSLATABLE|DI_ITEM_RIGHT
		);
	}
	//return value of the mag that would be selected on reload
	int GetNextLoadMag(hdmagammo maggg){
		if(!maggg||maggg.mags.size()<1)return -1;
		int maxperunit=maggg.maxperunit;
		int maxindex=maggg.mags.find(maxperunit);
		if(maxindex==maggg.mags.size())return maggg.mags[0];
		return maxperunit;
	}
}
