# Read the JSON response and extract text content
$json = Get-Content "D:/Ai_Project/cardnote_homo/temp_api.json" -Raw | ConvertFrom-Json

function Extract-TextFromBlock($block) {
    if ($block.block) {
        foreach ($key in $block.block.Keys) {
            $b = $block.block[$key]
            if ($b.type) {
                if ($b.type -eq "paragraph" -or $b.type -eq "text") {
                    if ($b.paragraph) {
                        foreach ($child in $b.paragraph.content) {
                            if ($child.text -and $child.text.content) {
                                $text = $child.text.content
                                # Decode HTML entities
                                $text = $text -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'"
                                Write-Output $text
                            }
                        }
                    }
                } elseif ($b.type -eq "heading_1" -or $b.type -eq "heading_2" -or $b.type -eq "heading_3") {
                    $level = $b.type -replace "heading_", "#"
                    if ($b.($b.type)) {
                        foreach ($child in ($b.($b.type)).content) {
                            if ($child.text -and $child.text.content) {
                                $text = $child.text.content
                                $text = $text -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'"
                                Write-Output "$level $text"
                            }
                        }
                    }
                } elseif ($b.type -eq "bulleted_list_item" -or $b.type -eq "numbered_list_item") {
                    Extract-TextFromBlock $b
                } elseif ($b.type -eq "to_do") {
                    Extract-TextFromBlock $b
                } elseif ($b.type -eq "code") {
                    if ($b.code) {
                        Write-Output "```"
                        foreach ($child in $b.code.content) {
                            if ($child.text -and $child.text.content) {
                                Write-Output $child.text.content
                            }
                        }
                        Write-Output "```"
                    }
                } elseif ($b.type -eq "sub_header" -or $b.type -eq "sub_sub_header") {
                    $level = if ($b.type -eq "sub_header") { "##" } else { "###" }
                    if ($b.($b.type)) {
                        foreach ($child in ($b.($b.type)).content) {
                            if ($child.text -and $child.text.content) {
                                $text = $child.text.content
                                $text = $text -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#39;', "'"
                                Write-Output "$level $text"
                            }
                        }
                    }
                } else {
                    # Recursively extract from children
                    if ($b.type -eq "child_page") {
                        Write-Output "---"
                        Write-Output "# $($b.child_page.title)"
                        Write-Output "---"
                    }
                    # Try to extract from any 'content' array
                    if ($b.content) {
                        foreach ($child in $b.content) {
                            # Find the actual child block
                            # The child has a UUID key, look for text in it
                        }
                    }
                }
            } else {
                # Nested block
                Extract-TextFromBlock $b
            }
        }
    }
}

Extract-TextFromBlock $json
