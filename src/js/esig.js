

Make sure the following is in the showrec
%?isesig?%         <input type="button" id="esig_btn" class="btn btn-green b_medium esig" value="Approve" />

TYPE 1 -- single step esigs:
	workflow.cfg / cimconfig.cfg
		esiglist:DistribDesignation|DDApprove$|function|getDDEsig					<--- NO TRAILING ';'

		esiglist:IC_CollegeCommittee|IC Committee|function|getColCommitteeEsig
		esiglist:IC_CollegeFaculty|IC Faculty|function|getColFacultyEsig

	workflow.tcf
		...
		Col Committee fyi,
		Col Committee,
		...
		Col Faculty fyi,
		Col Faculty,
		...

	workflowFuncs.atj
		wffuncs.getColCommitteeEsig = function(data) {
			return getEsigs(data, "Committee");
		}
		wffuncs.getColFacultyEsig = function(data) {
			return getEsigs(data, "Faculty");
		}

		function getEsigs(data, type) {
			// AS - Arts & Sciences
			// BU - Business & Economics
			// ED - Education
			// EN - Engineering

			// subj CSB goes to EN, BU
			// subj IBE goes to EN, BU
			// subj IDEA goes to AS, EN
			// dept AE goes to AS, EN
			// dept GCP goes to AS, EN, BU
			var ret = [];

			if(data.department && data.department.length && data.subject && data.subject.length) {
				if(data.department[0].code == "AE") {
					ret.push("EN " + type);
					ret.push("AS " + type);
				} else if (data.subject[0].code == "IBE" || data.subject[0].code == "CSB") {
					ret.push("EN " + type);
					ret.push("BU " + type);
				} else if(data.subject[0].code == "IDEA") {
					ret.push("AS " + type);
					ret.push("EN " + type);
				} else if(data.subject[0].code == "GCP") {
					ret.push("AS " + type);
					ret.push("BU " + type);
					ret.push("EN " + type);
				} else if(data.department[0].code == "IDPC" && data.subject[0].code == "ENTP") {
					ret.push("BU " + type);
					ret.push("EN " + type);
				}
			}
			return ret;
		};






TYPE 2 -- multiple step esigs (e.g. yale courseadmin):
	workflow.cfg / cimconfig.cfg
		esiglist:DistribDesignation|DDApprove$|function|getDDEsig
				 attributeName      RolePattern         stepInjectionFunctionName

	workflow.tcf
		...
		DDApprove fyi,
		...
		DDApprove,
		...

	workflowFuncs.atj
		wffuncs.getDDEsig = function(data) {
			var ret = [];
			var hasd1 = false;
			var hasd2 = false;
			var val;
			for(var i=0; data.distribdesignation && i < data.distribdesignation.length; i++) {
				if(typeof data.distribdesignation[i] == "string")
					val = data.distribdesignation[i];
				else
					val = data.distribdesignation[i].code;
				var code = val.replace(/^YC/, "");
				if(!/L[1-4]$/.test(code))
					ret.push("DDReview" + code);
				if(val.indexOf("FLL") === 0)
					hasd2 = true;
				else
					hasd1 = true;
			}
			/*
			if(hasd1)
				ret.push("DDReview");
			if(hasd2)
				ret.push("DDReviewFLL");
			*/
			return ret;
		};


