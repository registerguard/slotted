Include Audience

Class custom.rg.Slots Extends (%Persistent, %Populate, %XML.Adaptor)
{

/// The <method>getStories</method> ClassMethod gets the slotted stories from a user defined Section.
/// Based on DTI's <class>dt.cms.support.TopSlotStories</class>.
/// 
/// @see https://groups.google.com/d/topic/dti-lightning/5avEj-4twNE/discussion
/// @see https://github.com/registerguard/custom.rg.GetStoriesRule
/// 
/// @param publication { %String } Required. Publication name.
/// @param section { %String } Required. Section name.
/// @param layout { %String } Required. Page Layout name.
/// @param grid { %String } Required. Grid name.
/// @param area { %String } Required. Area(s) name.
/// @param items { %String } Number of CMSStory objects to return. The default is 5.
/// @param include { %String } Include only these slots (comma delimited list).
/// @param exclude { %String } Exclude only these slots (comma delimited list).
/// @param version { %String } Staging version(s) to pull from.
/// @param order { %String } Custom ORDER BY used in SQL statement.
ClassMethod getStories(
	publication As %String = "",
	section As %String = "",
	layout As %String = "",
	grid As %String = "",
	area As %String = "",
	items As %Integer = 5,
	include As %String = "",
	exclude As %String = "",
	version As %Integer = 0,
	order As %String = "") As %List
{
	
	/**
	 * Trims white space and builds a list.
	 *
	 * set items = "foo, bar, baz"
	 * $$$lister(items) // "items" is now a list.
	 *
	 * @see https://groups.google.com/d/topic/intersystems-public-cache/8iJV1p3kwD8/discussion
	 * @see https://gist.github.com/4008569
	 *
	 * @param %list { string } Comma delimited list; this argument must be passed as a variable (not a string).
	 * @return %List
	 */
	
	#define lister(%list)                                                                   ##Continue
		set temp = ""                                                                       ##Continue
		for ##Unique(new)=1:1:$length(%list, ",") {                                         ##Continue
			set temp = temp _ $listbuild($zstrip($piece(%list, ",", ##Unique(old)), "<>W")) ##Continue
		}                                                                                   ##Continue
		set %list = temp
	
	/*----------------------------------*/
	
	/**
	 * Creates an array of key => values.
	 *
	 * $$$pbuild("areaID")
	 * $$$pbuild("sectionId")
	 * w params(1)
	 * // someMethod(params...)
	 *
	 * @see http://rgne.ws/QjjrSx
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
		
		/*----------------------------------*/
		
		; Convert comma delimited string of Area(s) into a $list:
		$$$lister(area)
		
		; Convert comma delimited string of Staging Version(s) into a $list:
		$$$lister(version) // -1 = staged, 0 = live, 1 = rollback 1, 2 = rollback 2 ... (see "ContentPublisher" >> "Web Site" >> "Staging Version" for more info).
		
		/*----------------------------------*/
		
		; Build query:
		set sql =
			"SELECT TOP ? mp.cmsStory " _ 
			"FROM dt_cms_schema.section se, dt_cms_schema.Publication pb, dt_cms_schema.PageLayout pl, dt_cms_schema.Grid gr, dt_cms_schema.Area ar, dt_cms_schema.Slot sl, dt_cms_schema.mapping mp " _ 
			"WHERE se.publicationid = pb.ID " _ 
			"AND pl.publicationid = se.publicationid " _ 
			"AND gr.pageLayoutID = pl.ID " _ 
			"AND gr.ID = ar.gridID " _ 
			"AND sl.areaID = ar.ID " _ 
			"AND mp.slotReferenceID = sl.slotReferenceID " _ 
			"AND mp.sectionId = se.%ID " _ 
			"AND pb.name = ? " _        // publication
			"AND se.name = ? " _        // section
			"AND pl.name = ? " _        // pagelayoutname
			"AND gr.name = ? " _        // grid
			"AND ar.name %INLIST ? " _  // area
			"AND mp.version %INLIST ? " // version
		
		/*----------------------------------*/
		
		; Setup "params" array for required input parameters:
		$$$pbuild(items)
		$$$pbuild(publication)
		$$$pbuild(section)
		$$$pbuild(layout)
		$$$pbuild(grid)
		$$$pbuild(area)
		$$$pbuild(version)
		
		/*----------------------------------*/
		
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
			
			; Add include list to params:
			$$$pbuild(exclude)
			
			; Amend query:
			set sql = sql _ "AND sl.slotReferenceID->name NOT %INLIST ? "
			
		}
		
		/*----------------------------------*/
		
		; Order by what?
		set sql = sql _ "ORDER BY " _ $select($length(order):order, 1:"mp.slotReferenceID ASC")
		
		/*----------------------------------*/
		
		; Output debug?
		if (debug) {
			
			do ##class(dt.cms.support.Rules).debugRule(debug, "<p>sql=" _ sql _ "</p>")
			
			do ##class(dt.cms.support.Rules).debugRule(debug, "<p>items=" _ items _ " publication=" _ publication _ " section=" _ section _ " pagelayoutname=" _ layout _ " grid=" _ grid _ " area=" _ area _ " items=" _ items _ " include=" _ include _ " exclude=" _ exclude _ " version=" _ version _ " orderby=" _ order _ "</p>")
			
		}
		
		/*----------------------------------*/
		
		try {
			
			set packages = "" // Used for resolving unqualified table references (it's best, and faster, to fully qualify tables with their scheme).
			
			; No need for:
			//set rs = ##class(%ResultSet.SQL).%New()
			
			; Prepare and execute the query:
			set rs = ##class(%ResultSet.SQL).%Prepare(sql, .error, packages, params...) // @@UNS: Use $$$dtQueryGet(sql, params...)
			
			if ($isobject(error)) {
				
				$$$dtThrow($$$dtSysErr(error.Status),"Failed to execute: ##class(%ResultSet.SQL).%Prepare(""" _ $get(sql) _ """)")
				
			} else {
				
				; Initialize the status code:
				set sc = $$$OK
				
				//while (rs.%Next(.sc) && ($$$ISOK(sc))) { // Recommended to $$$ISERR() below.
				while (rs.%Next(.sc)) {
					
					; If there's a problem, exit the loop:
					quit:($$$ISERR(sc))
					
					; Return the results in a list:
					do return.Insert(##class(dt.cms.schema.CMSStory).%OpenId(rs.%GetData(1),, .sc))
					
					$$$dtThrow(sc, "Failed to open CMSStory: ##class(dt.cms.schema.CMSStory).%OpenId(" _ rs.%GetData(1) _ ")")
					
				}
				
				$$$dtThrow(sc, "Failed to get query element: rs.%Next(.sc)")
				
				//do rs.Close() // Defunct. Better to use:
				kill rs // ... or set rs = ""
				
			}
			
		} catch(e) {
			
			$$$dtThrow(e.AsStatus(), "Something failed.")
			
		}
		
		/*----------------------------------*/
		
	}
	
	quit return
}

}
