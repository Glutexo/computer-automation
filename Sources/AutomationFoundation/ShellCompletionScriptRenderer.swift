public enum ShellCompletionScriptRenderer {
    public static func zsh(executableName: String) -> String {
        """
        #compdef \(executableName)

        _\(sanitize(functionName: executableName))() {
          local -a completions
          completions=("${(@f)$(\(executableName) --complete "${words[@]:1}")}")
          _describe 'values' completions
        }

        _\(sanitize(functionName: executableName)) "$@"
        """
    }

    private static func sanitize(functionName: String) -> String {
        String(functionName.map { character in
            character == "-" ? "_" : character
        })
    }
}
