from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image ,ImageDraw

ROOT =Path (__file__ ).resolve ().parent .parent
SHEETS =ROOT /"assets"/"sheets"
OUT =ROOT /"assets"/"art"

VARIETY_IDS =["yellow","orange","lime","green","teal","cyan",
"sky_blue","blue","pink","brown","gray","white"]

PROPS =["warning_sign","checkpoint_flag","shield_pickup","slowmo_clock",
"suspension_bridge","chain_fence","broken_pipe","lantern_post"]
UI =["slot_idle","slot_selected","icon_trampoline","icon_ramp",
"icon_wall","cooldown_bar","keycap_1","keycap_2",
"keycap_3","keycap_space","distance_badge","game_over_panel"]
CHARACTERS =["ball_idle","ball_rolling","ball_bouncing","ball_dead",
"dead_ball_hazard","devil_ball_hazard","spike","floor",
"trampoline_idle","trampoline_bouncing","speed_booster","particle_bounce",
"particle_death","coin",None ,None ]

def background_alpha (rgb :np .ndarray ,bg :np .ndarray )->tuple [np .ndarray ,np .ndarray ]:
	c =rgb .astype (np .float32 )/255.0
	b =bg .astype (np .float32 )/255.0
	up =np .where (c >b ,(c -b )/np .maximum (1.0 -b ,1e-4 ),0.0 )
	down =np .where (c <b ,(b -c )/np .maximum (b ,1e-4 ),0.0 )
	alpha =np .clip (np .max (np .maximum (up ,down ),axis =2 ),0.0 ,1.0 )
	safe =np .maximum (alpha ,1e-4 )[...,None ]
	colour =np .clip ((c -b )/safe +b ,0.0 ,1.0 )
	return alpha ,colour

def flood_background (rgb :np .ndarray ,bg :np .ndarray ,tol :float )->np .ndarray :
	h ,w ,_ =rgb .shape
	close =np .abs (rgb .astype (np .int16 )-bg .astype (np .int16 )).max (axis =2 )<=tol
	seen =np .zeros ((h ,w ),bool )
	q :deque =deque ()
	for x in range (w ):
		for y in (0 ,h -1 ):
			if close [y ,x ]and not seen [y ,x ]:
				seen [y ,x ]=True
				q .append ((y ,x ))
	for y in range (h ):
		for x in (0 ,w -1 ):
			if close [y ,x ]and not seen [y ,x ]:
				seen [y ,x ]=True
				q .append ((y ,x ))
	while q :
		y ,x =q .popleft ()
		for dy ,dx in ((1 ,0 ),(-1 ,0 ),(0 ,1 ),(0 ,-1 )):
			ny ,nx =y +dy ,x +dx
			if 0 <=ny <h and 0 <=nx <w and close [ny ,nx ]and not seen [ny ,nx ]:
				seen [ny ,nx ]=True
				q .append ((ny ,nx ))
	return seen

def dilate (mask :np .ndarray ,steps :int )->np .ndarray :
	m =mask .copy ()
	for _ in range (steps ):
		n =m .copy ()
		n [1 :,:]|=m [:-1 ,:]
		n [:-1 ,:]|=m [1 :,:]
		n [:,1 :]|=m [:,:-1 ]
		n [:,:-1 ]|=m [:,1 :]
		m =n
	return m

def cut (region :Image .Image ,tol :float =70.0 ,pad :int =4 )->Image .Image :
	rgb =np .asarray (region .convert ("RGB"))
	bg =np .median (np .concatenate ([rgb [0 ],rgb [-1 ],rgb [:,0 ],rgb [:,-1 ]]),axis =0 )
	outside =flood_background (rgb ,bg ,tol )
	edge =dilate (outside ,3 )
	alpha ,colour =background_alpha (rgb ,bg )
	out_a =np .where (edge ,alpha ,1.0 )
	out_rgb =np .where (edge [...,None ],colour ,rgb .astype (np .float32 )/255.0 )
	rgba =np .dstack ([out_rgb ,out_a ])
	img =Image .fromarray ((rgba *255.0 +0.5 ).astype (np .uint8 ),"RGBA")
	a =np .asarray (img )[...,3 ]
	ys ,xs =np .nonzero (a >6 )
	if len (xs )==0 :
		return img
	box =(max (0 ,xs .min ()-pad ),max (0 ,ys .min ()-pad ),min (img .width ,xs .max ()+1 +pad ),min (img .height ,ys .max ()+1 +pad ))
	return img .crop (box )

def slice_grid (sheet :Path ,names :list ,cols :int ,cell_w :int ,row_h :int ,art_h :int )->None :
	img =Image .open (sheet ).convert ("RGB")
	for i ,name in enumerate (names ):
		if not name :
			continue
		c ,r =i %cols ,i //cols
		box =(c *cell_w +2 ,r *row_h +2 ,(c +1 )*cell_w -2 ,r *row_h +art_h )
		cut (img .crop (box )).save (OUT /f"{name }.png")

def slice_varieties (sheet :Path )->None :
	img =Image .open (sheet ).convert ("RGBA")
	scale =4
	for i ,vid in enumerate (VARIETY_IDS ):
		c ,r =i %4 ,i //4
		cx ,cy ,radius =130 +c *260 ,130 +r *294 ,96
		box =(cx -radius -2 ,cy -radius -2 ,cx +radius +2 ,cy +radius +2 )
		crop =img .crop (box )
		size =crop .width
		mask =Image .new ("L",(size *scale ,size *scale ),0 )
		ImageDraw .Draw (mask ).ellipse ((2 *scale ,2 *scale ,(size -2 )*scale -1 ,(size -2 )*scale -1 ),fill =255 )
		crop .putalpha (mask .resize ((size ,size ),Image .LANCZOS ))
		crop .save (OUT /f"variety_{vid }.png")

def recolour_dead (target_ids :list )->None :
	base =Image .open (OUT /"ball_dead.png").convert ("RGBA")
	hsv =np .asarray (base .convert ("RGB").convert ("HSV")).astype (np .float32 )
	alpha =np .asarray (base )[...,3 ]
	yellow_px =(hsv [...,1 ]>70 )&(hsv [...,2 ]>60 )
	ref =np .asarray (Image .open (OUT /"variety_yellow.png").convert ("HSV")).astype (np .float32 )
	ref_mask =np .asarray (Image .open (OUT /"variety_yellow.png"))[...,3 ]>200
	ref_s ,ref_v =ref [...,1 ][ref_mask ].mean (),ref [...,2 ][ref_mask ].mean ()
	for vid in target_ids :
		tgt_img =Image .open (OUT /f"variety_{vid }.png")
		tgt =np .asarray (tgt_img .convert ("HSV")).astype (np .float32 )
		m =np .asarray (tgt_img )[...,3 ]>200
		t_h =np .median (tgt [...,0 ][m ])
		t_s ,t_v =tgt [...,1 ][m ].mean (),tgt [...,2 ][m ].mean ()
		out =hsv .copy ()
		out [...,0 ]=np .where (yellow_px ,t_h ,out [...,0 ])
		out [...,1 ]=np .where (yellow_px ,np .clip (out [...,1 ]*t_s /ref_s ,0 ,255 ),out [...,1 ])
		out [...,2 ]=np .where (yellow_px ,np .clip (out [...,2 ]*t_v /ref_v ,0 ,255 ),out [...,2 ])
		rgb =Image .fromarray (out .astype (np .uint8 ),"HSV").convert ("RGB")
		rgb .putalpha (Image .fromarray (alpha ))
		rgb .save (OUT /f"variety_{vid }_dead.png")

def main ()->None :
	OUT .mkdir (parents =True ,exist_ok =True )
	slice_grid (SHEETS /"props.png",PROPS ,4 ,300 ,334 ,292 )
	slice_grid (SHEETS /"ui.png",UI ,4 ,300 ,334 ,292 )
	slice_grid (SHEETS /"characters.png",CHARACTERS ,4 ,300 ,334 ,292 )
	print ("wrote",len (list (OUT .glob ("*.png"))),"sprites to",OUT )

if __name__ =="__main__":
	main ()
