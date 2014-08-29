#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

package require http
package require mysqltcl
# HTTP Configuration #####################################
set city "delhi"
set citycode 20070458 

set urlw "http://weather.yahooapis.com/forecastrss?u=c&w="
set urli "http://where.yahooapis.com/v1/places.q(\'"

set pname proxy62.iitd.ernet.in
set pport 3128
set appid "\')?appid=IBgxbd3V34ErG9nPkhKeH_tDdZKO0p0SkushhJI.j0bAuE5ONpwmJ90kjEF3kppRZZWBRuYkhhybO5Vd3kGAbBhSsahAlAk-"
::http::config -proxyhost $pname -proxyport $pport
# mySQL Configuration #######################################
set usr root
set pass dbpass
set datab predictapp
set sqltoken [mysql::connect -user $usr -password $pass]
::mysql::exec $sqltoken "CREATE DATABASE IF NOT EXISTS $datab;"
::mysql::use $sqltoken $datab
::mysql::exec $sqltoken " CREATE TABLE IF NOT EXISTS temprecord (\
						  city int DEFAULT NULL,\
						  date DATE DEFAULT NULL,\
						  day varchar(10) DEFAULT NULL,\
						  low SMALLINT DEFAULT NULL,\
						  high SMALLINT DEFAULT NULL,\
						  code SMALLINT DEFAULT NULL,\
						  description varchar(50) DEFAULT NULL);"
::mysql::exec $sqltoken " DELETE FROM temprecord WHERE DATEDIFF(CURDATE(),date)>30;"
::mysql::exec $sqltoken " CREATE TABLE IF NOT EXISTS lastcity (code int DEFAULT NULL, \
																cityname varchar(100) DEFAULT NULL,\
																temp varchar(100) DEFAULT NULL,\
																date varchar(100) DEFAULT NULL,\
																text varchar(100) DEFAULT NULL,\
															    image SMALLINT DEFAULT NULL);"

# Variables #############################################
set mlst {25 "00" "Failed to Download" "Showing stored information" "Connection Failed" 20070458}
set temp 21
set tmpfind 21
set tmpsw -22
set tmprefresh 0
set refreshing 0
### Download RSS Feed and extract data #####################################################################################################
proc getwoe {} {
	if {[catch {set token [http::geturl $::urli$::city$::appid]} msg]} {
			puts "Error Contacting Yahoo api: $msg"
			return 0
	} else {
		set tdata [http::data $token]
		regexp {<woeid>([^<>]+)} $tdata  -> datastr0
		if {[catch {set cde $datastr0}]} {
			puts "Invalid Place"
			return 0
		} else {
			set ::citycode $cde
			return 1
		}
	}		
}

proc refreshdb {} {
		
	if {[catch {set token [http::geturl $::urlw$::citycode]} msg]} {
		puts "Error Contacting Yahoo Weather: $msg"
			lset ::mlst 3 "Showing stored information"
	} else {
		set tdata [http::data $token]


		regexp {<yweather:condition[ ]+([^<>]+)} $tdata  -> datastr0
		if {[info exists datastr0]==0} {
			puts "Invalid Yahoo Weather Data"
			lset ::mlst 3 "Showing stored information"
			return 0
		}		
			
		set ::mlst { }
		regexp -nocase {code=\"([^\"]*)} $datastr0 -> dtstr
		lappend ::mlst $dtstr
		regexp -nocase {temp=\"([^\"]*)} $datastr0 -> dtstr
		lappend ::mlst $dtstr
		regexp -nocase {text=\"([^\"]*)} $datastr0 -> dtstr
		lappend ::mlst $dtstr
		regexp -nocase {date=\"([^\"]*)} $datastr0 -> dtstr
		lappend ::mlst $dtstr

		regexp {<yweather:location[ ]+([^<>]+)} $tdata  -> datastr0
		regexp -nocase {city=\"([^\"]*)} $datastr0 -> dtstr
		regexp -nocase {region=\"([^\"]*)} $datastr0 -> dtstr1
		lappend ::mlst "$dtstr $dtstr1"

		::mysql::exec $::sqltoken "DELETE FROM lastcity;"
		::mysql::exec $::sqltoken "INSERT INTO lastcity(code,cityname,temp,date,text,image)\
					 VALUES ($::citycode,'[lindex $::mlst 4]','[lindex $::mlst 1]','Showing Stored information','[lindex $::mlst 2]'\
					 ,'[lindex $::mlst 0]');"

		set datalist [regexp -inline -all {<yweather:forecast[ ]+[^<>]+} $tdata]

		foreach datastr0 $datalist {
				regexp -nocase {day=\"([^\"]*)} $datastr0 -> sday
				regexp -nocase {date=\"([^\"]*)} $datastr0 -> sdate
				regexp -nocase {low=\"([^\"]*)} $datastr0 -> slow
				regexp -nocase {high=\"([^\"]*)} $datastr0 -> shigh
				regexp -nocase {text=\"([^\"]*)} $datastr0 -> stext
				regexp -nocase {code=\"([^\"]*)} $datastr0 -> scode

				::mysql::exec $::sqltoken "DELETE FROM temprecord WHERE date=STR_TO_DATE('$sdate', '%d %b %Y') AND city='$::citycode';"	
				::mysql::exec $::sqltoken "INSERT INTO temprecord(day,date,low,high,description,code,city)\
								 		 VALUES ('$sday',STR_TO_DATE('$sdate', '%d %b %Y'), '$slow','$shigh','$stext','$scode','$::citycode');"
		}
		::http::cleanup $token
	}
	return 1
}
proc refreshdata {} {
	set ::lst [::mysql::sel $::sqltoken "SELECT DATE_FORMAT(date,'%d %b %Y'),code,high,low,description FROM temprecord WHERE city='$::citycode' ORDER BY date;" -list] 
}


set ::mlst [::mysql::sel $::sqltoken "SELECT image,temp,text,date,cityname,code FROM lastcity;" -flatlist] 
if {[llength $::mlst]==0} {
	set mlst {25 "00" "Failed to Download" "Showing stored information" "Connection Failed" 20070458}
}
set citycode [lindex $mlst 5]
refreshdb
refreshdata
if {[llength $::lst]==0} {
	set ::lst {{"25 Jan 2014" 01 46 34 "Product Initiation"} {"26 Jan 2014" 20 69 2 "Started on GUI"} {"27 Jan 2014" 25 67 9 "Project Submission"}}
	set ::index 0
	set ::tindex $::index
	set ::cind $::index
} else {
	set ::index [expr [llength $::lst] - 5]
	set ::tindex $::index
	set ::cind $::index
}
# Import Data from database #####################################

#################################################################

package require Tk
# Image Data ####################################################
image create photo back -file back.gif
image create photo hi -file high.gif
image create photo lo -file low.gif

set param .gif
set ilst { }
for {set i 0} {$i<47} {incr i} {
	lappend ilst [image create photo -file $i$param]
}
################################################################

# GUI Description #######################################################################################################################
set im [image create photo -file icon.gif]
wm iconphoto . -default $im

wm title . "THE WEATHER APP"
wm geometry . 400x310
wm resizable . 0 0
grid [tk::canvas .canvas] -sticky nwes -column 0 -row 0
grid columnconfigure . 0 -weight 1
grid rowconfigure . 0 -weight 1

ttk::entry .text -textvariable username -font "helvetica 15"
ttk::button .b1 -text "Choose" -command "query"
ttk::button .b2 -text "Forecast" -command "stforcast" 
.canvas create image 200 186 -image back -tags "back"

proc crtmain {plst off} {
	.canvas create image [expr $off + 400] 5 -image [lindex $::ilst [lindex $plst 0]] -anchor ne -tags "main"
	.canvas create text [expr $off + 113] 0 -text [lindex $plst 1] -anchor ne -font "helvetica 60" -tags "main" -fill white
	.canvas create text [expr $off + 115] 8 -text "o" -anchor nw -font "helvetica 20 bold" -tags "main" -fill white
	.canvas create text [expr $off + 135] 12 -text "C" -anchor nw -font "helvetica 30" -tags "main" -fill white
	.canvas create text [expr $off + 120] 70 -text [lindex $plst 4] -anchor w -font "helvetica 13 underline" -tags "main place" -fill white
	.canvas create text [expr $off + 25] 95 -text [lindex $plst 3] -anchor w -font "helvetica 10" -tags "main status" -fill white
	.canvas create text [expr $off + 25] 115 -text "Currently : [lindex $plst 2]" -anchor w -font "helvetica 12 bold" -tags "main" -fill white
}

proc crtbox {plst off1 off2} {
	.canvas create rectangle [expr $off1 + 20] [expr 140 + $off2] [expr $off1 + 270] [expr 300 + $off2]  -tags "uni" -outline white
	.canvas create text [expr $off1 +  255] [expr 150 + $off2] -text [lindex $plst 0] -font "helvetica 12" -anchor ne -tags "uni" -fill white
	.canvas create image [expr $off1 + 20] [expr 152 + $off2] -image [lindex $::ilst [lindex $plst 1]] -anchor nw -tags "uni"
	.canvas create image [expr $off1 + 225] [expr 145 + $off2] -image hi  -anchor ne -tags "uni"
	.canvas create image [expr $off1 + 225] [expr 195 + $off2] -image lo  -anchor ne -tags "uni"
	.canvas create text [expr $off1 + 260] [expr 170 + $off2] -text [lindex $plst 2] -font "helvetica 32" -anchor ne -tags "uni" -fill white
	.canvas create text [expr $off1 + 260] [expr 219 + $off2] -text [lindex $plst 3] -font "helvetica 32" -anchor ne -tags "uni" -fill white
	.canvas create text [expr $off1 + 145] [expr 282 + $off2] -text [lindex $plst 4] -font "helvetica 12 bold"  -tags "uni" -fill white
}
proc crtplace {off} {
	.canvas create rectangle 140 [expr 140 + $off] 380 [expr 290 + $off]  -tags "usr" -outline white
	.canvas create text 260 [expr 158 + $off] -text "Place Finder" -font "helvetica 12 bold" -tags "usr" -fill white
	.canvas create line 140 [expr 170 + $off] 380 [expr 170 + $off] -tags "usr" -fill white
	.canvas create text 155 [expr 193 + $off] -text "Type new location" -font "helvetica 11" -anchor w -tags "usr" -fill white
	.canvas create window 155 [expr 225 + $off] -window .text -anchor w -width 210 -height 27 -tags "usr"
	.canvas create window 155 [expr 265 + $off] -window .b1 -anchor w -width 90 -height 27 -tags "usr"
	.canvas create window 365 [expr 265 + $off] -window .b2 -anchor e -width 90 -height 27 -tags "usr"
}
## GUI Description End ######################################################################################################################

### HTTP Section End #######################################################################################################################

crtmain $mlst 0
crtbox [lindex $lst $index] 0 0
proc every {ms body} {
    eval $body; after $ms [info level 0]
}

proc stforcast {} {
	if {$::tmpsw==22 && $::refreshing==0} {
		crtbox [lindex $::lst $::index] 0 250
		set ::tmpsw -1
	}
}

proc stplace {} {
	if {$::tmpsw==-22 && $::temp==21 && $::refreshing==0} {
		mouseleave
		crtplace 250
		set ::tmpsw 1
	}
}

proc query {} {
	if {$::tmpsw==22 && $::refreshing==0} {
		.b1 state disabled
		.b2 state disabled
		regsub -all " " [::.text get] "%20" ::city
		if {[::getwoe]} {
			if {[::refreshdb]} {
				refreshdata
				set ::index [expr [llength $::lst] - 5]
				set ::tindex $::index
				set ::cind $::index
				.canvas coords back {200 186}
				.canvas addtag old withtag main
				crtmain $::mlst 400
				set ::tmpfind 0
			} 
		}
		.b1 state !disabled
		.b2 state !disabled
	}
}
proc refresh {} {
	 if {$::temp==21 && $::tmpfind==21} {
			if {$::tmpsw==-22} {
				if {[::refreshdb]} {
					::refreshdata
				}
				.canvas addtag old withtag main
			 	.canvas addtag old withtag uni
				::crtmain $::mlst 0
				::crtbox [lindex $::lst $::index] 0 0
				.canvas delete old	
				set ::refreshing 0	
				set ::tmprefresh 0
			} elseif  {$::tmpsw==22} {
				if {[::refreshdb]} {
					::refreshdata
				}
				.canvas addtag old withtag main
				::crtmain $::mlst 0
				.canvas delete old
				set ::refreshing 0
				set ::tmprefresh 0
			}
		}
}
proc lclk {x y} {
	if {$::temp==21 && $::tmpsw==-22 && $y>135 && $::refreshing==0} {
		if {$x>200} {
			if {[expr $::index + 1]<[llength $::lst]} {
				incr ::index
			}
		} else {
			if {$::index>0} {
				incr ::index -1
			}
		}
	}
}
proc mouseenter {} {
	if {$::tmpsw==-22} {
		.canvas itemconfigure place -fill green
	}
}
proc mouseleave {} {
	if {$::tmpsw==-22} {
		.canvas itemconfigure place -fill white
	}
}
bind .canvas <1> "lclk %x %y"

.canvas bind place <Enter> "mouseenter"
.canvas bind place <Leave> "mouseleave"
.canvas bind place <1> "stplace"

proc Slide {} {
	if {$::tmprefresh==2500} {
		.canvas itemconfigure status -text "Refreshing"
	} elseif {$::tmprefresh>2500} {
		set ::refreshing 1
		::refresh	
	}
	incr ::tmprefresh	
	 if {$::tmpsw<11 && $::tmpsw>0} {
		.canvas move uni 0 25
		incr ::tmpsw
	} elseif {$::tmpsw>-11 && $::tmpsw<0} {
		.canvas move usr 0 25
		incr ::tmpsw -1
	} elseif {$::tmpsw<21 && $::tmpsw>0} {
		.canvas move usr 0 -25
		incr ::tmpsw
	} elseif {$::tmpsw>-21 && $::tmpsw<0} {
		.canvas move uni 0 -25
		incr ::tmpsw -1
	} elseif {$::tmpsw==21} {
		::.canvas delete uni
		incr ::tmpsw
	} elseif {$::tmpsw==-21} {
		::.canvas delete usr
		incr ::tmpsw -1
	} 

	if {$::tmpfind<20} {
		.canvas move main -20 0
		incr ::tmpfind
	} elseif {$::tmpfind==20} {
		incr ::tmpfind
		.canvas delete old
		.b1 state !disabled
		.b2 state !disabled
	}

	if {$::temp<20} {
		if {$::index>$::cind} {
			.canvas move uni -20 0
			if {[expr $::cind - $::tindex]<4 && [expr $::cind - $::tindex]>-5} {.canvas move back -10 0}
		} else {
			.canvas move uni 20 0
			if {[expr $::cind - $::tindex]<5 && [expr $::cind - $::tindex]>-4} {.canvas move back 10 0}
		}
		incr ::temp
	} elseif {$::temp==20} {
		if {$::index>$::cind} {incr ::cind} else {incr ::cind -1}
		incr ::temp
		::.canvas delete old
	} elseif {$::index<$::cind} {
		::.canvas addtag old withtag uni 
		crtbox [lindex $::lst [expr $::cind - 1]] -400 0
		set ::temp 0
	} elseif {$::index>$::cind} {
		::.canvas addtag old withtag uni 
		crtbox [lindex $::lst [expr $::cind + 1]] 400 0
		set ::temp 0
	}
}
every 25 {Slide}
