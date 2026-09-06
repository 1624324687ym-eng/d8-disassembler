void Shell::LoadBytecode(const v8::FunctionCallbackInfo<v8::Value>& info) {
    auto isolate = info.GetIsolate();
    auto isolateInternal = reinterpret_cast<v8::internal::Isolate*>(isolate);

    if (info.Length() < 1) {
        isolate->ThrowException(v8::Exception::Error(
            v8::String::NewFromUtf8(isolate, "No args found.").ToLocalChecked()));
        return;
    }

    v8::String::Utf8Value filename(isolate, info[0]);
    if (*filename == NULL) {
        isolate->ThrowException(v8::Exception::Error(
            v8::String::NewFromUtf8(isolate, "Error creating filename.").ToLocalChecked()));
        return;
    }

    // Version-agnostic file reading (Shell::ReadChars signature changed in V8 15)
    FILE* fp = fopen(*filename, "rb");
    if (!fp) {
        isolate->ThrowException(v8::Exception::Error(
            v8::String::NewFromUtf8(isolate, "Error reading file.").ToLocalChecked()));
        return;
    }
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    std::unique_ptr<char[]> raw_filedata(new char[fsize]);
    size_t fsize_read = fread(raw_filedata.get(), 1, fsize, fp);
    fclose(fp);
    int length = static_cast<int>(fsize_read);

    auto filedata = reinterpret_cast<uint8_t*>(raw_filedata.get());
    v8::internal::AlignedCachedData cached_data(filedata, length);
    auto source = isolateInternal->factory()
        ->NewStringFromUtf8(base::CStrVector("source"))
        .ToHandleChecked();
    v8::internal::ScriptDetails script_details;

    setvbuf(stdout, nullptr, _IONBF, 0);
    printf("===== START DESERIALIZE BYTECODE =====\n");
    fflush(stdout);
    v8::internal::CodeSerializer::Deserialize(isolateInternal, &cached_data, source, script_details);
    printf("===== DONE DESERIALIZE BYTECODE =====\n");
    fflush(stdout);
}
