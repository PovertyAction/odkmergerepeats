/*----------------------------------------*
 |file:    odkmergerepeats.ado            |
 |authors: christopher boyer              |
 |         innovations for poverty action |
 |version: v1.0.0						  |
 |date:    2016-01-30                     |
 *----------------------------------------*
*/

cap program drop odkmergerepeats _recurserepeats _recursemerge _reshaperepeat 

program define odkmergerepeats, rclass
	// this program merges and reshapes data from ODK nested repeat groups,
	// which are often output as separate data sets, into a single WIDE 
	// data set.
	version 13

	syntax using/, [long]

    // load master data set
    use "`using'", replace

	// create master tempfile 
	tempfile master
	local childfiles : list childfiles | master
	save `master', replace
	
    // identify repeat groups
    unab setof : setof*
	gettoken var : setof
	
    // recurse through the repeats 
	_recurserepeats "`var'" "`childfiles'"
end

program define _recurserepeats, rclass
	// _recurserepeats is a recursive helper function that 
	// finds and opens the file associated with the repeat group 
	// and checks for nested repeats.

	// define private locals
	local node `1'
	local tmplist `2'
	local child `3'
	local repeatlist `4'
	
	// check if any other setof variables
	unab setof : setof*
	local branches : list setof - node
	local anybranches : list sizeof branches
	
	// extract repeat name from setof variable and find file
	local oldrepeat : list node in repeatlist
	
	if !`oldrepeat' {
		// add repeat name to repeatlist
		local repeatlist : list repeatlist | node
		local repeat : subinstr local node "setof" ""
		
		// find corresponding dta file
		local dta : dir . files "*`repeat'.dta"
		use `dta', clear
			 
		// create a temp file and add it to the child list
		tempfile tmp
		local tmplist : list tmplist | tmp
		qui save `tmp', replace
			
		// check if any nested setof variables
		unab setof : setof*
		local nests : list setof - node
		local anynests : list sizeof nests
	}
	else {
		local nests = ""
		local anynests = 0
		local tmp `child'
	}	
	
	// if there are nests
    if `anynests' {
		// get the first and start recursing down
        gettoken innervar : nests
        _recurserepeats "`innervar'" "`tmplist'" "`tmp'" "`repeatlist'"
    }
	// if there are no nests
    else {
		// calculate the current position
		local pos : list posof "`tmp'" in tmplist

		// if not master
        if `pos' > 1 {
			local upone = `pos' - 1
			local parent : word `upone' of `tmplist'
			local parentfiles : list tmplist - tmp
			_reshaperepeat "`tmp'" "`node'"
			_recursemerge "`parentfiles'" "`tmp'" "`node'" "`repeatlist'"
        }
	}
end

program define _recursemerge
	// _recursemerge is a recursive helper function that is called
	// when the end of a nested chain is reached. It merges the
	// last child with the parent and then checks for additional
	// nests in the parent.

	// define private locals
	local parentfiles `1' 
	local child `2'
	local node `3'
	local repeatlist `4'
	
	// extract most recent parent from the list
	local wc : word count `parentfiles'
	local parent : word `wc' of `parentfiles'
	
	use `parent', clear
	
	tempvar merge
    unab setof : setof*
    assert "`setof'" != ""
	
	tempvar order
    generate `order' = _n
    if !_N ///
        tostring key, replace
    qui merge key using `child', sort _merge(`merge')
    qui tabulate `merge'
    assert `merge' != 2
    sort `order'
    drop `order' `merge'
	
	// list
	unab before : _all
    qui describe using "`child'", varlist
    local childvars `r(varlist)'
    local overlap : list before & childvars
    local KEY key
    local overlap : list overlap - KEY	
	
	unab after : _all
    local new : list after - before
    foreach var of local new {
        move `var' `node'
    }
	
	// calculate remaining setof variables
	local branches : list setof - node
	local anybranches : list sizeof branches
	
	drop `node'

	// save
	qui save `parent', replace
	
	if `anybranches' {
		// get the first
		gettoken first : branches
		
		// check for nests and either recurse or continue merge
		_recurserepeats "`first'" "`parentfiles'" "`parent'" "`repeatlist'"
	}
end

program define _reshaperepeat
	// _reshaperepeat reshapes the current node to WIDE format.
	
	// define private local
	local child `1'
	local node `2'
	
	// reshape to WIDE
	
	if "`node'" != "" {
		drop `node'
	}
	drop key 
	
	// add underscore to variables ending in a number
	qui ds parent_key, not
    foreach var in `r(varlist)' {
        if inrange(substr("`var'", -1, 1), "0", "9") & length("`var'") < 30 {
            capture confirm new variable `var'_
            if !_rc ///
                rename `var' `var'_
        }
    }

	// 
    if _N {
        tempvar j
        sort parent_key, stable
        by parent_key: generate `j' = _n
        qui ds parent_key `j', not
        qui reshape wide `r(varlist)', i(parent_key) j(`j')

        // Restore variable labels.
        foreach var of varlist _all {
            *mata: st_varlabel("`var'", st_global("`var'[Odk_label]"))
        }
    }
    else {
        qui ds parent_key, not
        foreach var in `r(varlist)' {
            ren `var' `var'1
        }

        drop parent_key
        gen parent_key = ""
    }

    rename parent_key key

	// save
	qui save `child', replace
end
