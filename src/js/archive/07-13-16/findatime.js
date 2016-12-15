
function makeApiCall(){
	$("#sdate").datepicker({minDate:new Date()});
	$("#edate").datepicker({minDate:new Date()});
	showtoday(new Date(),"primary");
	$("#sdate").change(changeedate);
	$("#exportme").click(exportme);
	$("#killit").click(killitf);
	$("#popup").draggable({handle:"h2"});
	var emails = [];
	gapi.client.load('calendar', 'v3',function(){
		var result = gapi.client.calendar.calendarList.list({
			maxResults:250,
			});
		result.execute(function(res){
			console.log(res);
			for(i=0;i<res.items.length;i++){
				emails.push($("<option text='"+res.items[i].summary+"' value='"+res.items[i].id+"'>"+res.items[i].summary+"</option>"));
			}
			
			$("#email").append(emails.sort(function (a,b){
				var aID = $(a).attr('text').toLowerCase();
				var bID = $(b).attr('text').toLowerCase();
				return (aID == bID) ? 0 : (aID > bID) ? 1 : -1;
			}));
		})
	});
	$("#email").change(showtime);
}
function showtime(){
	$.ajax({
		url:"/ribbit/index.cgi?page=checkworkday.rjs&email="+$("#email").val(),
		success:function(xml){
			if($(xml).find("workhours").text()!=""){
				$("#workday").text(" Work Hours: "+$(xml).find("workhours").text());
			}
		}
	})
	
	
}
function killitf(){
	$("#popup").hide();
}
function changeedate(){
	var nd = new Date($("#sdate").val());
	nd.setDate(nd.getDate()+5);
	$("#edate").datepicker("option","maxDate",nd);
}

function exportme(){
	var text = "";
	$("#content .today").each(function(){
		text += $(this).find('.head').text()+"\n";
		var last = $(this).find(".row:first-child");
		if($(last).find('.free').length > 0){
			text += $(last).find(".time").text()+" ";
		}
		$(this).find('.row').each(function(){
			if($(last).find('.free').length > 0 && $(this).find('.free').length > 0){
				//text += "until "+$(last).find(".time").text()+"\n";
			}
			if($(last).find('.busy').length > 0 && $(this).find('.free').length > 0){
				text += $(this).find(".time").text()+" ";
			}
			if($(last).find('.free').length > 0 && $(this).find('.busy').length > 0){
				text += "until "+$(this).find(".time").text()+"\n";
			}
			last = this;
		});
		if($(last).find('.free').length > 0){
			text += "until " + $(last).find(".time").text();
		}
		text += "\n\n";
	});

	$("#popup textarea").val(text);
	$("#popup").show();
}



function showdays(callback){
	$("#content").empty();
	var d = new Date($("#sdate").val());
	var e = new Date($("#edate").val());
	var j = 0;
	var email = $("#email").val();
	while(d<=e){
		var divj = $("<div id='div"+j+"' class='today'></div>");
		$(divj).append("<div class='head'>"+$.datepicker.formatDate('DD MM dd',d)+"</div>");
		$("#content").append(divj)
		showtoday(d,email,divj);
		d.setDate(d.getDate()+1);
		j++;
	};
	$("#buttonbar").show();
}



function showtoday(datetoshow,email,done){
	if(!datetoshow){return false};
	if(datetoshow == 'Invalid Date' || datetoshow == ""){datetoshow = new Date()}
	if(!email){email = 'primary'}
	findtrainertime(email,new Date(datetoshow),function(busygrid){
		var td = busygrid.date;
		
		td = td.getFullYear()+"-"+td.getMonth()+"-"+td.getDate();
		var today = $("<div id='"+td+"'></div>");
		var j=0;
		
		for(i=480;i<1035;i=i+30){
			j++;
			var eo;
			if(j%2 == 0){
				eo = 'even';
			}
			else{
				eo = 'odd';
			}
			var time = Math.floor(i/60);
			if(time > 12){ampm = "PM";time = time-12}else if(time == 12){ampm = "PM";}else{ampm = "AM"}
			time+=":"
			if(i%60 == 0){time += "00"}else{time += i%60};
			time+=" "+ampm;
			var row = $("<div class='row "+eo+"' id='min-"+i+"'><span class='time'>"+time+"</span></div>");
			if(busygrid[i] == 0){
				$(row).append("<span class='busy'>busy</span>");
			}
			else{
				$(row).append("<span class='free'>free</span>");
			}
			$(today).append(row);
		}
		$(done).append(today);
	});
	
}

function findtrainertime(temail,tdate,callback){
var today = new Date(tdate);
today.setHours(0);
today.setMinutes(0);
today.setSeconds(0);
var tm = new Date(tdate);
tm.setHours(23);
tm.setMinutes(59);
tm.setSeconds(59);
gapi.client.load('calendar', 'v3',function(){
		var result = gapi.client.calendar.events.list({
			calendarId:temail,
			timeMin:today.toISOString(),
			singleEvents:true,
			timeMax:tm.toISOString(),
			});
		result.execute(function(res){
				if(res.error){
					console.log(res);
				}
				else{
					busygrid = {};
					for(d=0;d<1440;d=d+15){ //1440 minutes in a day
						busygrid[d]=1; // every 15 minutes in the day
					}
					for(cnt=0;cnt<res.items.length;cnt++){
						var ev = res.items[cnt];
						ev.startdate = new Date(ev.start.dateTime || ev.start.date);
						ev.startdate = ev.startdate.getFullYear()+'-'+ev.startdate.getMonth()+'-'+ev.startdate.getDate();
						// appt in day
						if(ev.start.dateTime){
							//minper
							ev.starttime = new Date(ev.start.dateTime);
							var hrs = ev.starttime.getHours();
							var min = (hrs * 60)+parseInt(ev.starttime.getMinutes());
							var minper;
							for(d=0;d<1440;d=d+15){ //1440 minutes in a day
								var nextd = d+15;
								if(min >=d && min < nextd){
									minper = d;
									break;
								}
							}
							//maxper
							ev.endtime = new Date(ev.end.dateTime);
							var hrs = ev.endtime.getHours();
							var min = (hrs * 60)+parseInt(ev.endtime.getMinutes());
							var maxper;
							for(d=0;d<1440;d=d+15){ //1440 minutes in a day
								var nextd = d+15;
								if(min > d && min <= nextd){
									maxper = d;
									break;
								}
							}
							busygrid[minper]=0;
							for(b=minper+15;b<maxper;b=b+15){
								busygrid[b]=0;
							}
							busygrid[maxper]=0;
						}
						//all day
						else{
							console.log(ev.startdate);
							for(d=0;d<1440;d=d+15){ //1440 minutes in a day
								busygrid[d]=0;
							}
						}
					}
					busygrid.date = today;
					return callback(busygrid);
				}
			});
		
	});
}