Include Audience

/// custom.rg.Slotted
/// See <code>custom.rg.GetStoriesRule</code> for related code.
/// 
/// @docs https://github.com/registerguard/slotted
/// @copyright Copyright (c) 2013 Micky Hulse/The Register-Guard.
/// @license Released under the Apache License, Version 2.0.
/// http://www.apache.org/licenses/LICENSE-2.0
/// @version 3.0.0
/// @date Monday, January 7, 2013
Class custom.rg.Slotted Extends %RegisteredObject
{

/// The <method>stories</method> ClassMethod returns a %ListOfObjects of <class>dt.cms.schema.Mapping</class> objects from an Area(s) in a Section.
/// Based on DTI's <class>dt.cms.support.TopSlotStories</class>.
/// Many thanks goes to DTI, Joy and Eric for the pro help and inspiration.
/// 
/// @see https://groups.google.com/d/topic/dti-lightning/5avEj-4twNE/discussion
/// @see https://github.com/registerguard/slotted/issues/2
/// @see https://github.com/registerguard/slotted/issues/10
/// 
/// @param publication { %String } Publication name (required).
/// @param section { %String } Section name (required).
/// @param layout { %String } Page Layout name (required).
/// @param grid { %String } Grid name (required).
/// @param area { %String } Area(s) name (required).
/// @param items { %String } Number of Mapping objects to return; the default number is '5'.
/// @param include { %String } Include only these Slots (comma delimited list).
/// @param exclude { %String } Exclude only these Slots (comma delimited list).
/// @param version { %String } Staging Version(s) to pull from; '0' (live) used by default.
/// @param order { %String } Custom ORDER BY, used in SQL statement.
ClassMethod stories(
	publication As %String = "",
	section As %String = "",
	layout As %String = "",
	grid As %String = "",
	area As %String = "",
	items As %Integer = 5,
	include As %String = "",
	exclude As %String = "",
	version As %String = "0",
	order As %String = "") As %ListOfObjects
{

	/**
	 * Trims white space and builds a list.
	 *
	 * set items = "foo, bar, baz"
	 * $$$lister(items) // "items" is now a list.
	 *
	 * @todo Force %list argument into a string before processing? Example: set %list = %list _ ""
	 *
	 * @see https://groups.google.com/d/topic/intersystems-public-cache/8iJV1p3kwD8/discussion
	 * @see https://gist.github.com/4008569
	 *
	 * @param %list { string } Comma delimited list; this argument must be passed as a variable (not a string).
	 * @return { $list } The %list parameter as a $list.
	 */

	#define lister(%list)                                                                   ##Continue
		set temp = ""                                                                       ##Continue
		for ##Unique(new)=1:1:$length(%list, ",") {                                         ##Continue
			set temp = temp _ $listbuild($zstrip($piece(%list, ",", ##Unique(old)), "<>W")) ##Continue
		}                                                                                   ##Continue
		set %list = temp                                                                    ##Continue
		kill temp

	/*----------------------------------*/

	/**
	 * Creates an array of key => values.
	 *
	 * $$$pbuild("areaID")
	 * $$$pbuild("sectionId")
	 * w params(1)
	 * // someMethod(params...)
	 *
	 * @see http://docs.intersystems.com/cache20091/csp/docbook/DocBook.UI.Page.cls?KEY=GOBJ_methods#GOBJ_methods_args_variable
	 * @see https://groups.google.com/d/topic/dti-lightning/5avEj-4twNE/discussion
	 *
	 * @param %v { mixed } Key value for "params" array.
	 * @return { array } Numerically indexed array of values.
	 */

	#define pbuild(%v) set params($increment(params)) = %v

	/*--------------------------------------------------------------------*/

	; Initialze the return value:
	set return = ##class(%ListOfObjects).%New()

	; Check required arguments:
	if ($length(publication) && $length(section) && $length(layout) && $length(grid) && $length(area)) {
	
		; Get RULE debug:
		set debug = ##class(dt.cms.support.Rules).getDebug()
	
		; Convert comma delimited string of Area(s) into a $list:
		$$$lister(area)
	
		; Convert comma delimited string of Staging Version(s) into a $list:
		$$$lister(version) // -1 = staged, 0 = live, 1 = rollback 1, 2 = rollback 2 ... (see "ContentPublisher" >> "Web Site" >> "Staging Version" for more info).
	
		; Build query:
		set sql =
			"SELECT TOP ? mp.%Id AS Mapping " _ // https://groups.google.com/d/msg/intersystems-public-cache/zMp4JZqRKog/xPvYgfIIz58J
			"FROM dt_cms_schema.Section se, dt_cms_schema.Publication pb, dt_cms_schema.PageLayout pl, dt_cms_schema.Grid gr, dt_cms_schema.Area ar, dt_cms_schema.Slot sl, dt_cms_schema.Mapping mp " _ 
			"WHERE se.publicationID = pb.ID " _ 
			"AND pl.publicationID = se.publicationID " _ 
			"AND gr.pageLayoutID = pl.ID " _ 
			"AND gr.ID = ar.gridID " _ 
			"AND sl.areaID = ar.ID " _ 
			"AND mp.slotReferenceID = sl.slotReferenceID " _ 
			"AND mp.sectionID = se.%ID " _ 
			"AND pb.name = ? " _        // publication
			"AND se.name = ? " _        // section
			"AND pl.name = ? " _        // layout
			"AND gr.name = ? " _        // grid
			"AND ar.name %INLIST ? " _  // area
			"AND mp.version %INLIST ? " // version
	
		; Copy/paste friendly:
		/*
			SELECT TOP 10 mp.%Id AS Mapping 
			FROM dt_cms_schema.Section se, dt_cms_schema.Publication pb, dt_cms_schema.PageLayout pl, dt_cms_schema.Grid gr, dt_cms_schema.Area ar, dt_cms_schema.Slot sl, dt_cms_schema.Mapping mp 
			WHERE se.publicationID = pb.ID 
			AND pl.publicationID = se.publicationID 
			AND gr.pageLayoutID = pl.ID 
			AND gr.ID = ar.gridID 
			AND sl.areaID = ar.ID 
			AND mp.slotReferenceID = sl.slotReferenceID 
			AND mp.sectionID = se.%ID 
			AND pb.name = 'rg' 
			AND se.name = 'sports' 
			AND pl.name = 'sports' 
			AND gr.name = 'Default' 
			AND ar.name = 'Stories' 
			AND mp.version = '0' 
			ORDER BY mp.slotReferenceID ASC
		*/
	
		; Setup "params" array for required input parameters:
		$$$pbuild(items)
		$$$pbuild(publication)
		$$$pbuild(section)
		$$$pbuild(layout)
		$$$pbuild(grid)
		$$$pbuild(area)
		$$$pbuild(version)
	
		; Includes?
		if ($length(include)) {
		
			; Convert comma delimited string of Slot Names(s) "indludes" into a $list:
			$$$lister(include)
		
			; Add include list to params:
			$$$pbuild(include)
		
			; Amend query:
			set sql = sql _ "AND sl.slotReferenceID->name %INLIST ? "
		
		}
	
		; Excludes?
		if ($length(exclude)) {
		
			; Convert comma delimited string of Slot Names(s) "excludes" into a $list:
			$$$lister(exclude)
		
			; Add exclude list to params:
			$$$pbuild(exclude)
		
			; Amend query:
			set sql = sql _ "AND sl.slotReferenceID->name NOT %INLIST ? "
		
		}
	
		; Order by what?
		set sql = sql _ "ORDER BY " _ $select($length(order):order, 1:"mp.slotReferenceID ASC")
	
		; Output debug?
		if (debug) {
		
			; The query:
			do ##class(dt.cms.support.Rules).debugRule(debug, "sql = " _ sql)
		
			; ClassMethod arguements:
			do ##class(dt.cms.support.Rules).debugRule(debug, "##class(custom.rg.Slotted).stories(publication=""" _ publication _ """ section=""" _ section _ """ layout=""" _ layout _ """ grid=""" _ grid _ """ area=""" _ $listtostring(area, ", ") _ """ items=""" _ items _ """ include=""" _ $listtostring(include, ", ") _ """ exclude=""" _ $listtostring(exclude, ", ") _ """ version=""" _ $listtostring(version, ", ") _ """ order=""" _ order _ """)")
		
		}
	
		; Try/catch block required when using $$$dtThrow:
		try {
		
			; %importPackages:
			set packages = "" // Used for resolving unqualified table references (it's best, and faster, to fully qualify tables with their scheme).
		
			; No need for:
			//set rs = ##class(%ResultSet.SQL).%New() // http://docs.intersystems.com/cache20091/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_dynsql#GSQL_dynsql_resultset
		
			; Prepare and execute the query:
			set rs = ##class(%ResultSet.SQL).%Prepare(sql, .error, packages, params...) // @@UNS: Use $$$dtQueryGet(sql, params...)
		
			; An error will be a %SYSTEM.Error object:
			if ($isobject(error)) {
			
				; Throws if %sc is an error:
				$$$dtThrow($$$dtSysErr(error.Status),"Failed to execute: ##class(%ResultSet.SQL).%Prepare(""" _ $get(sql) _ """)")
			
			} else {
			
				; Initialize the status code:
				set sc = $$$OK
			
				//while (rs.%Next(.sc) && ($$$ISOK(sc))) { // Recommended to $$$ISERR() below.
				while (rs.%Next(.sc)) {
				
					; If there's a problem, exit the loop:
					quit:($$$ISERR(sc))
				
					; Return the results in a list:
					set sc = return.Insert(rs.Mapping) // Inserts an element with OREF value oref at the end of the list. Returns a %Status value indicating success or failure. 
				
					; Throws if %sc is an error:
					$$$dtThrow(sc, "Failed to insert Mapping: return.Insert(" _ rs.Mapping _ ")")
				
				}
			
				; Throws if %sc is an error:
				$$$dtThrow(sc, "Failed to get query element: rs.%Next(.sc)")
			
				//do rs.Close() // Defunct. Better to use:
				kill rs // ... or set rs = ""
			
			}
		
		} catch(e) {
		
			; Throws if %sc is an error:
			$$$dtThrow(e.AsStatus(), "Something failed.")
		
		}
	
	}

	; Return the %ListOfObjects:
	quit return
}

}
