Import-Module (Join-Path $PSScriptRoot "..\utils.psm1")

function Patch {
    param([string]$Content)
    
    $deserializerSignature = "Deserializer<IsolateT>::Deserializer"
    $Content = Add-LineBelow -Content $Content `
        -Patterns @($deserializerSignature, '#endif') `
        -Insert "  /*"
    $Content = Add-LineBelow -Content $Content `
        -Patterns @($deserializerSignature, 'CHECK_EQ') `
        -Insert "  */"

    # Trace every bytecode with its stream offset so a crash pinpoints the
    # exact position where the producer/consumer formats diverge.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "Deserializer<IsolateT>::ReadSingleBytecodeData" `
        -Converter {
        param($Body)
        return "  PrintF(`"[pos=%d byte=%02x]`", static_cast<int>(source_.position()) - 1, data);`n" + $Body
    }

    # Trace new-object allocations with space, size and map instance type.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "Deserializer<IsolateT>::ReadObject" `
        -Parameter "SnapshotSpace space" `
        -Converter {
        param($Body)
        $Body = Add-LineBelow -Content $Body `
            -Patterns @('DirectHandle<Map> map = Cast<Map>\(ReadObject\(\)\);') `
            -Insert '  PrintF("[newobj space=%d size=%d itype=%d]", (int)space, size_in_tagged, (int)map->instance_type());'
        return $Body
    }

    # Trace back-reference indices before the hardened vector access.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "Deserializer<IsolateT>::GetBackReferencedObject" `
        -Parameter "uint32_t index" `
        -Converter {
        param($Body)
        $Body = Add-LineBefore -Content $Body `
            -Pattern 'Handle<HeapObject> obj = back_refs_\[index\];' `
            -Insert '  PrintF("[backref=%u size=%zu]", index, back_refs_.size());'
        return $Body
    }

    return $Content
}
