Import-Module (Join-Path $PSScriptRoot "..\utils.psm1")

function Patch {
    param([string]$Content)

    # Producer's external-reference table differs slightly from this d8 build
    # (Electron embeds node/Chromium refs), so the dedup sentinel
    # (producer kSizeIsolateIndependent) does not equal this build's constant.
    # Dedup indices are always < any plausible table size (~1700), while the
    # sentinel is larger (~3170) -- so a fixed threshold cleanly separates them.
    # The table itself is never dereferenced here (CHECK removed): this pass
    # only consumes the stream so root deserialization starts at the right byte.
    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "void StartupDeserializer::DeserializeAndCheckExternalReferenceTable" `
        -Converter {
        param($Body)
        return @'
  ExternalReferenceTable* table = isolate()->external_reference_table();
  while (true) {
    uint32_t index = source()->GetUint30();
    if (index >= 2000) break;  // sentinel: producer kSizeIsolateIndependent
    uint32_t encoded_index = source()->GetUint30();
  }
'@
    }

    return $Content
}
