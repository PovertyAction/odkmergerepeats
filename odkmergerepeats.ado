/*----------------------------------------*
 |file:    odkmergerepeats.ado            |
 |authors: christopher boyer              |
 |         innovations for poverty action |
 |version: v1.0.0						  |
 |date:    2016-01-30                     |
 *----------------------------------------*
*/

cap program drop odkmergerepeats _recurserepeats _recursemerge _reshaperepeat _checkfornests

program define odkmergerepeats, rclass
	// this program merges and reshapes data from ODK nested repeat groups,
	// which are often output as separate data sets, into a single WIDE 
	// data set.
	version 13

	syntax using/, [long]

    // load master data set
    use "`using'", replace

	tempfile child
	local childfiles : list childfiles | child
	
    // identify repeat groups
    unab setof : setof*
	
    // recurse through the repeats 
	foreach var of varlist `setof' {
		_recurserepeats "`var'" "`childfiles'"
	}
end

// _recurserepeats
program define _recurserepeats, rclass
    local node `1'
    local childfiles "`2'"
	
	di "node is `node'"
	di "child files are `childfiles'"
	
    local repeat : subinstr local node "setof" ""
    local dta : dir . files "*`repeat'.dta"
	
    use `dta', clear
	
	tempfile child
	local childfiles : list childfiles | child
	
	_checkfornests "`node'" "`childfiles'" "`child'"
end

program define _recursemerge
	local parentfiles `1' 
	local child `2'
	
	local wc : word count `parentfiles'
	local parent : word `wc' of `parentfiles'
	
    di "Merging `child' in to `parent'."
	unab before : _all
    describe using "`child'", varlist
    local childvars `r(varlist)'
    local overlap : list before & childvars
    local KEY KEY
    local overlap : list overlap - KEY	
	di "here"
	//local parentfiles : list parentfiles - parent
	
	// this line needs to be edited.
	_checkfornests "`overlap'" "`parentfiles'" "`parent'"
end

program define _reshaperepeat
	local node `1'
    di "Reshaping `node' to WIDE format."
	save `node', replace
end

program define _checkfornests 
	local node `1'
	local tmplist `2'
	local child `3'
	di "`node'"
	
    unab setof : setof*
	local nests : list setof - node
    local anynests : list sizeof nests
	
    if `anynests' {
        gettoken innervar : nests
		di "Found `innervar' in `node'"
        _recurserepeats "`innervar'" "`tmplist'"
    }
    else {
		local pos : list posof "`child'" in tmplist
		di "`pos'"
        if `pos' > 1 {
			local upone = `pos' - 1
			local parent : word `upone' of `tmplist'
			di "here"
            local parentfiles : list tmplist - child
			_reshaperepeat "`child'"
			_recursemerge "`parentfiles'" "`child'"
        }
		else {
			di "Done?"
		}
	}
end
    
/*
// _mergerepeats
program define _mergerepeat, rclass
    tempvar merge
    unab setof : setof*
    assert "`setof'" != ""

    unab before : _all
    local repeatname : subinstr "setof" "" `0'
    local child : dir . files "*`repeatname'.dta"
    describe using `child', varlist
    local childvars `r(varlist)'
    local overlap : list before & childvars
    local KEY KEY
    local overlap : list overlap - KEY
    quietly if `:list sizeof overlap' {
        gettoken first : overlap
        noisily display as err "error merging repeat group repeat1 and repeat group `repeat'"
        noisily display as err "variable `first' exists in both datasets"
        noisily display as err "rename it in one or both, then try again"
        exit 9
    }

    tempvar order
    generate `order' = _n
    if !_N ///
        tostring KEY, replace
    merge KEY using `child', sort _merge(`merge')
    tabulate `merge'
    assert `merge' != 2
    sort `order'
    drop `order' `merge'

    unab after : _all
    local new : list after - before
    foreach var of local new {
        move `var' `setof'
    }
    drop `setof'
end

// _reshaperepeat
program define _reshaperepeat
    ds PARENT_KEY, not
    foreach var in `r(varlist)' {
        if inrange(substr("`var'", -1, 1), "0", "9") & length("`var'") < 30 {
            capture confirm new variable `var'_
            if !_rc ///
                rename `var' `var'_
        }
    }

    if _N {
        tempvar j
        sort PARENT_KEY, stable
        by PARENT_KEY: generate `j' = _n
        ds PARENT_KEY `j', not
        reshape wide `r(varlist)', i(PARENT_KEY) j(`j')

        // Restore variable labels.
        foreach var of varlist _all {
            mata: st_varlabel("`var'", st_global("`var'[Odk_label]"))
        }
    }
    else {
        ds PARENT_KEY, not
        foreach var in `r(varlist)' {
            ren `var' `var'1
        }

        drop PARENT_KEY
        gen PARENT_KEY = ""
    }

    rename PARENT_KEY KEY

    local pos : list posof "repeat3" in repeats
    local child : word `pos' of `childfiles'
    save `child'
end



/*
program define _getfilepath, rclass
    version 8
    gettoken pathfile rest : 0
    if `"`rest'"' != "" {
        exit 198
    }
    gettoken word rest : pathfile, parse("\/:")
    while `"`rest'"' != "" {
        local path `"`macval(path)'`macval(word)'"'
        gettoken word rest : rest, parse("\/:")
    }
    if inlist(`"`word'"', "\", "/", ":") {
        di as err `"incomplete path-filename; ends in separator `word'"'
        exit 198
    }
    return local filename `"`word'"'
    return local path `"`path'"'
end
*/
