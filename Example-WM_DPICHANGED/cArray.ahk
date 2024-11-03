#Include cJSON.ahk

__ArrayEx__() {

    Array.prototype.DefineProp('Join', {Call: _join_})
    _Join_(self, returnValue := false, &outVar?, delim := ', ', start := 1, qty?) {
        delimLen := StrLen(delim)
        if returnValue {
            outVar := ''
            while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                item := self[start++]
                try
                    outVar .= String(item) delim
            }
            return (StrLen(outVar) > delimLen ? Trim(outVar, delim) : outVar)
        } else {
            excluded := [], outVar := ''
            while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                item := self[start++]
                try
                    outVar .= String(item) delim
                catch
                    excluded.Push(item)
            }
            outVar := (StrLen(outVar) > delimLen ? Trim(outVar, delim) : outVar)
            if excluded.length
                return excluded
        }
    }

    Array.prototype.DefineProp('JoinObj', {Call: _joinObj_})
    _JoinObj_(self, returnValue := false, &outVar?, delim := '`n', indentation := 4, start := 1, qty?) {
        delimLen := StrLen(delim)
        if returnValue {
            outVar := ''
            while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                item := self[start++]
                try
                    outVar .= String(item) delim
                catch {
                    try
                        outVar .= JSON.Stringify(item, indentation) delim
                }
            }
            return (StrLen(outVar) > delimLen ? Trim(outVar, delim) : outVar)
        } else {
            excluded := [], outVar := ''
            while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                item := self[start++]
                try
                    outVar .= String(item) delim
                catch {
                    try
                        outVar .= JSON.Stringify(item, indentation) delim
                    catch
                        excluded.Push(item)
                }
            }
            outVar := (StrLen(outVar) > delimLen ? Trim(outVar, delim) : outVar)
            if excluded.length
                return excluded
        }
    }

    Array.prototype.DefineProp('IndexOf', {Call: _IndexOf_})
    _IndexOf_(self, item, ignoreType := true, caseSense := false, start := 1, qty?) {
        if IsObject(item)
            throw Error('Objects are mutable and cannot be compared by value. Two like objects are not equal, even if their property names and values are the same.', -1)
        if caseSense {
            if ignoreType {
                while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                    if self[start++] == item
                        return start - 1
                }
            } else {
                while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                    if self[start++] == item && type(self[start-1]) == type(item)
                        return start - 1
                }
            }
        } else {
            if ignoreType {
                while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                    if self[start++] = item
                        return start - 1
                }
            } else {
                while start <= (IsSet(qty) && start + qty <= self.length ? start + qty : self.length) {
                    if self[start++] == item && type(self[start-1]) == type(item)
                        return start - 1
                }
            }
        }
    }
}

__ArrayEx__()

/* tests


/* Join
myarr := ['a', 'b', 'c', 'd', 'e', 'f']
if result := myarr.Join(&out)
    msgbox(1)
else
    msgbox(out)

/* Join with objects (should have error) and JoinObj (no error)

myarr := ['a', 'b', {c: 'c', d: 5}, Map('e', 'f')]
if result := myarr.Join(&out)
    msgbox(1)
else
    msgbox(out)

if result := myarr.JoinObj(&out)
    msgbox(1)
else
    msgbox(out)

/* IndexOf

_test_indexof() {

    myarr := ['a', 'b', 'c', 'd', 'e', 'f', 0, 1]

    ; case sense + ignore type
    casesense_ignoretype := Map(
        'upperchar', {expect:"", result:myarr.IndexOf('A', true, true)},
        'lowerchar', {expect:true, result:myarr.IndexOf('a', true, true)},
        'numstring', {expect:true, result:myarr.IndexOf('0', true, true)},
        'num', {expect:true, result:myarr.IndexOf(0, true, true)},
        'notinarraynum', {expect:"", result:myarr.IndexOf(2, true, true)},
        'notinarraychar', {expect:"", result:myarr.IndexOf('g', true, true)}
    )

    ; case sense + no ignore type
    casesense_noignoretype := Map(
        'upperchar', {expect:"", result:myarr.IndexOf('A', false, true)},
        'lowerchar', {expect:true, result:myarr.IndexOf('a', false, true)},
        'numstring', {expect:"", result:myarr.IndexOf('0', false, true)},
        'num', {expect:true, result:myarr.IndexOf(0, false, true)},
        'notinarraynum', {expect:"", result:myarr.IndexOf(2, false, true)},
        'notinarraychar', {expect:"", result:myarr.IndexOf('g', false, true)}
    )

    ; no case sense + ignore type
    nocasesense_ignoretype := Map(
        'upperchar', {expect:true, result:myarr.IndexOf('A', true, false)},
        'lowerchar', {expect:true, result:myarr.IndexOf('a', true, false)},
        'numstring', {expect:true, result:myarr.IndexOf('0', true, false)},
        'num', {expect:true, result:myarr.IndexOf(0, true, false)},
        'notinarraynum', {expect:"", result:myarr.IndexOf(2, true, false)},
        'notinarraychar', {expect:"", result:myarr.IndexOf('g', true, false)}
    )

    ; no case sense + no ignore type
    nocasesense_noignoretype := Map(
        'upperchar', {expect:"", result:myarr.IndexOf('A', false, false)},
        'lowerchar', {expect:true, result:myarr.IndexOf('a', false, false)},
        'numstring', {expect:"", result:myarr.IndexOf('0', false, false)},
        'num', {expect:true, result:myarr.IndexOf(0, false, false)},
        'notinarraynum', {expect:"", result:myarr.IndexOf(2, false, false)},
        'notinarraychar', {expect:"", result:myarr.IndexOf('g', false, false)}
    )

    problems := []
    for label, obj in Map('Case sense + Ignore Type', casesense_ignoretype
        , 'Case sense + No Ignore Type', casesense_noignoretype
    , 'No Case sense + Ignore Type', nocasesense_ignoretype
    , 'No Case sense + No Ignore Type', nocasesense_noignoretype) {
        for key, value in obj {
            if (value.result && !value.expect) || (!value.result && value.expect)
                problems.Push({function: label, keyval:Format('Key: {}, Expected: {}, Value: {}', key, value.expect, value.result)})
        }
    }
    if problems.length
        return problems
}


if result := _test_indexof() {
    str := JSON.Stringify(result, 4)
    A_Clipboard := str
    msgbox(str)
} else
    msgbox(1)
