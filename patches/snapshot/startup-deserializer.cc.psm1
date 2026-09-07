Import-Module (Join-Path $PSScriptRoot "..\utils.psm1")

function Patch {
    param([string]$Content)

    # The embedded Electron/node-integrated snapshot's external reference table
    # does not match this d8 binary (node/electron bindings are absent). The
    # verification is comment-only; the stream is still consumed correctly.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "void StartupDeserializer::DeserializeIntoIsolate" `
        -Converter {
        param($Body)
        $Body = Set-CommentLine -Content $Body -Pattern 'DeserializeAndCheckExternalReferenceTable\(\);'
        return $Body
    }

    # Also neutralize the CHECK inside the (now unused) verification helper.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "void StartupDeserializer::DeserializeAndCheckExternalReferenceTable" `
        -Converter {
        param($Body)
        $Body = Set-CommentLine -Content $Body -Pattern 'CHECK_EQ\(table->address\(index\), table->address\(encoded_index\)\);'
        return $Body
    }

    return $Content
}
