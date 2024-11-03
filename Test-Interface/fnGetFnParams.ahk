
class GetFnParamsFromScript extends GetFnParams {
    static Call(content_or_path) => GetFnParamsFromScript.prototype.__New(content_or_path)
    static patterns := {
        staticMethods: 'static (?P<method>[\w\d_]+)\((?P<params>[^>\r\n]*)\)'
      , instanceMethods: '(?P<method>[\w\d_]+)\((?P<params>[^>\r\n]*)\)'
    }
    __New(content_or_path) {
        content := this.content := (FileExist(content_or_path) ? FileRead(content_or_path) : content_or_path)
        methods := this.methods := Map()
        patterns := GetFnParamsFromScript.patterns
        while RegExMatch(content, patterns.staticMethods, &match, pos??1) {
            pos := match.pos + StrLen(match[0])
            if SubStr(match['method'], 1, 1) = '_' || match['method'] = 'ToggleModes' || match['method'] = 'Refresh'
                continue
            if match['method'] = 'Point'
                break
            methods.Set(match['method'], match['params'])
        }
    }
    static _GetMultiLine(content_or_path) {
        for method, params in methods {
            params := GetFnParams(params)
            p := Map('params', params, 'ctrls', Map(), 'flag_optional', false)
            for param in params {
                if InStr(param, '?') || InStr(param, ':=')
                    p['flag_optional'] := true
            }
            methods.Set(method, p)
            listMethods.push(method)
        }
    }

}

class GetFnParams {
    static _template := {bracketO: 0, bracketC: 0, parenO: 0, parenC: 0, squareO: 0, squareC: 0, singleQuote: false, doubleQuote: false, comma: 0}
    static Call(str) => GetFnParams._SingleLine(str)
    static _SingleLine(str) {
        static pattern := '([^`'"\{\(\}\),\]\[]*.(?C_callout_))+'
        matches := GetFnParams.matches := []
        GetFnParams.pos := 1
        GetFnParams.flag := false
        _SetVals_()
        while !_helper_()
            continue

        return GetFnParams.matches
        _helper_() {
            RegExMatch(str, pattern, &matchr, GetFnParams.pos)
            if !GetFnParams.flag && !matchr
                return 1
            if !GetFnParams.flag {
                matches.push(Trim(matchr[0], ' '))
                GetFnParams.pos := matchr.pos + StrLen(matchr[0])
            }
        }
        _SetVals_() {
            for k in GetFnParams._template.OwnProps()
                GetFnParams.DefineProp(k, {Value:0})
        }
    }
}
_callout_(match, cnumber, foundpos, haystack, needle) {
    GetFnParams.flag := false
    char := substr(match[0], -1, 1)
    if !GetFnParams.singleQuote && !GetFnParams.doubleQuote {
        switch char {
            case '{':
                GetFnParams.bracketO++
            case '}':
                GetFnParams.bracketC++
            case '(':
                GetFnParams.parenO++
            case ')':
                GetFnParams.parenC++
            case '[':
                GetFnParams.squareO++
            case ']':
                GetFnParams.squareC++
            case ',':
                GetFnParams.comma++
            case "'":
                GetFnParams.singleQuote := true
            case '"':
                GetFnParams.doubleQuote := true
        }
    } else {
        if GetFnParams.singleQuote {
            if char = "'" && _IsValidQuote_()
                GetFnParams.singleQuote := false
        }
        if GetFnParams.doubleQuote {
            if char = '"' && _IsValidQuote_()
                GetFnParams.doubleQuote := false
        }
    }
    if GetFnParams.bracketO = GetFnParams.bracketC && GetFnParams.parenO = GetFnParams.parenC && GetFnParams.squareO = GetFnParams.squareC && !GetFnParams.singleQuote && !GetFnParams.doubleQuote {
        if char = ',' {
            GetFnParams.flag := true
            GetFnParams.matches.push(Trim(match[0], ' ,'))
            GetFnParams.pos := foundpos + strlen(match[0])
            return -1
        }
    }

    _IsValidQuote_() {
        cnt := 0, i := -2
        while SubStr(match[0], i, 1) = '``'
            cnt++, i--
        return (Mod(cnt, 2) ? false : true)
    }
}