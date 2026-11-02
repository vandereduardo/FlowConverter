function run(argv) {
    if (argv.length < 2) {
        throw new Error("Usage: osascript -l JavaScript flow_pages_export.js <input> <output.pages>");
    }
    var srcPath = argv[0];
    var dstPath = argv[1];
    var Pages = Application("Pages");
    Pages.includeStandardAdditions = true;
    var doc = Pages.open(Path(srcPath));
    delay(0.5);
    Pages.save(doc, { in: Path(dstPath) });
    Pages.close(doc, { saving: "no" });
    return dstPath;
}
