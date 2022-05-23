## FIXME: This isn't a very good tree walker. I'm not actually sure what
## prewalking would mean semantically as I think about it for the first
## time... if you transform before recusing, there's a hornet's nest of infinite
## loops waiting down there. Maybe that's just how it is and you have to be
## careful, I've never needed to perform structural changes while walking.

""" leaves """
function walk(down, up, tree)
    up(tree)
end

function walk(down, up, tree::LispList)
    down(ArrayList(map(x -> walk(down, up, x), tree.elements)))
end

function walk(down, up, tree::LispVector)
    down(ArrayVector(map(x -> walk(down, up, x), tree.elements)))
end

function walk(down, up, tree::LispMap)
    down(ArrayMap(map(x -> walk(down, up, x), tree.kvs)))
end

function walk(down, up, tree::LispMapEntry)
    down(LispMapEntry(up(tree.key), up(tree.value)))
end

function postwalk(f, tree)
    walk(f, f, tree)
end

function t(x)
    if x == LispSymbol(nil, "x")
        LispNumber(0xa40)
    else
        x
    end
end
