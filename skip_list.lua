--- Skip list data structure.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local random = math.random

-- Modules --
local ffi = require("ffi")

-- Exports --
local M = {}

-- --
ffi.cdef[[
	struct _SkipListNode {
		int n;
		$ data;
		struct _SkipListNode * next[?];
	};
]]

local Node = ffi.typeof("_SkipListNode")

--- DOCME
function M.FindNode (head, value)
	local node = head

	for i = head.n - 1, 0, -1 do
		local next = node.next[i]

        while next.data < value do
            node, next = next, next.next[i]
        end

		if next.data == value then
			return next
		end
	end

	return nil
end

-- --
local PrevNodes

--
local function FindMaxNodesLessThan (head, value)
	local node = head

	for i = head.n - 1, 0, -1 do
		local next = node.next[i]

        while next.data < value do
            node, next = next, next.next[i]
        end

        PrevNodes[i] = node
	end
end

--- DOCME
function M.InsertValue (head, value)
	FindMaxNodesLessThan(head, value)

	local n = random(head.n)
	local node = Node(n, n)
	local prev = FindMaxNodeBefore(head, value)

	for i = 0, n - 1 do
		PrevNodes[i].next[i], node.next[i] = node, PrevNodes[i].next[i]
	end

	return node
end

-- --
local Inf = Node(1, 0, 1 / 0)

--- DOCME
function M.NewList (n)
    local head = Node(n, n)

	--
    for i = 0, n - 1 do
        head.next[i] = Inf
    end

	--
    if PrevNodes == nil or PrevNodes.n < n then
        PrevNodes = Node(1, n)
    end

	return head
end

--- DOCME
-- N.B. node is assumed to exist!
function M.RemoveNode (head, node)
    FindMaxNodesLessThan(head, node:GetValue())

	for i = 0, node.n - 1 do
		local prev = PrevNodes[i]

		while prev.next[i] ~= node do
			prev = prev.next[i]
		end

		prev.next[i] = node.next[i]
	end
end

--- DOCME
function M.RemoveValue (head, value)
    FindMaxNodesLessThan(head, value)

	--
	local n, node = head.n

	repeat
		n, node = n - 1, PrevNodes[n - 1].next
	until not (value < node.data) or n == 0

	--
	for i = 0, n - 1 do
		PrevNodes[i].next = node.next[i]
	end
		
	--
	return node
end

-- Node methods --
local SkipListNode = {}

--- DOCME
function SkipListNode:GetNextNode ()
	if self.next[0] ~= Inf then
		return self.next[0]
	else
		return nil
	end
end

--- DOCME
function SkipListNode:GetValue ()
	return self.data
end

--
ffi.metatype(Node, { __index = SkipListNode })

-- Export the module.
return M

--[[
--
--
-- SkipList.h
--
--
#ifndef SKIP_LIST_H
#define SKIP_LIST_H
/*** File skip_list.h - Skip List ***/
/*
 *   Shane Saunders
 */

/* Structure type for skip list nodes.  For flexibility, nodes point to items,
 * rather than having integer keys, and the skip list uses a comparison
 * function for comparing items.
 *   item - The nodes item.
 *   forward - An array of pointers pointing forward to other nodes in the
 *             list.
 *   size - the size of the forward array.  (i.e. the number of forward
 *          pointers the node has.)
 */
typedef struct skip_node {
    void *item;
    struct skip_node **forward;
    int size;
} skip_node_t;


/* Structure type definition for a skip list.
 *   head_ptrs - An array of head pointers.
 *   update - Is used when updating pointers after a node is inserted or
 *            deleted.  An entry, update[i] points to the node whose
 *            forward[i] pointer is to be updated.  The array is allocated
 *            when the list is created.  This prevents having to allocate and
 *            free the array for each insert or delete operation.
 *   p - The probability with which a node size is allocated.  p is always less
 *       than or equal to 1.  The probability of node being allocated sizes
 *       1, 2, 3, ... , n, is  p, p^2, p^3, ... , p^n, respectively.
 *   compar - A function for comparing items in the list.
 *   n - the number of items currently stored in the list.
 */
typedef struct skip_list {
    skip_node_t **head_ptrs;
    skip_node_t ***update;
    double p;
    int max_level;
    int (* compar)(const void *, const void *);
    int n;
} skip_list_t;



/* skip_list_alloc() - Allocates space for a skip list and returns a pointer to
 * it.  The parameter, max_n, specifies the expected maximum number of nodes to
 * be stored in the list. The parameter, prob, specifies the probability for
 * height increase when generating random node heights.  The function compar
 * compares they keys of two items, and returns a negative, zero, or positive
 * integer depending on whether the first item is less than, equal to, or
 * greater than the second.  
 */
skip_list_t *skip_list_alloc(int max_n, double prob, int (* compar)(const void *, const void *));

/* skip_list_free() - Frees space used by the skip list pointed to by t. */
void skip_list_free(skip_list_t *t);

/* skip_list_insert() - Inserts an item into the skip list pointed to by t,
 * according the the value its key.  The key of an item in the skip list must
 * be unique among items in the list.  If an item with the same key already
 * exists in the list, a pointer to that item is returned.  Otherwise, NULL is
 * returned, indicating insertion was successful.
 */
void *skip_list_insert(skip_list_t *t, void *item);

/* skip_list_find() - Find an item in the skip list with the same key as the
 * item pointed to by `key_item'.  Returns a pointer to the item found, or NULL
 * if no item was found.
 */
void *skip_list_find(skip_list_t *t, void *key_item);

/* skip_list_find_min() - Returns a pointer to the minimum item in the skip
 * list pointed to by t.  If there are no items in the list a NULL pointer is
 * returned.
 */
void *skip_list_find_min(skip_list_t *t);

/* skip_list_delete() - Delete the first item found in the skip list with
 * the same key as the item pointed to by `key_item'.  Returns a pointer to the
 * deleted item, and NULL if no item was found.
 */
void *skip_list_delete(skip_list_t *t, void *item);

/* skip_list_delete_min() - Deletes the item with the smallest key from the
 * skip list pointed to by t.  Returns a pointer to the deleted item.
 * Returns a NULL pointer if there are no items in the list.
 */
void *skip_list_delete_min(skip_list_t *t);

#endif
--]]

--[[
--
--
-- SkipList.c
--
--
/*** File skip_list.c - Skip List ***/
/*
 *   Shane Saunders
 */

/* skip_list_alloc() - Allocates space for a skip list and returns a pointer to
 * it.  The parameter, max_n, specifies the expected maximum number of nodes to
 * be stored in the list. The parameter, prob, specifies the probability for
 * height increase when generating random node heights.  The function compar
 * compares they keys of two items, and returns a negative, zero, or positive
 * integer depending on whether the first item is less than, equal to, or
 * greater than the second.  
 */
skip_list_t *skip_list_alloc(int max_n, double prob,
			     int (* compar)(const void *, const void *))
{
    int i, max_level;
    skip_list_t *t;
    skip_node_t **head_ptrs;

    
    t = malloc(sizeof(skip_list_t));
    t->p = prob;
    t->compar = compar;
    max_level = t->max_level = -log(max_n)/log(prob);

    /* All searches start from the trees head pointers. */
    head_ptrs = t->head_ptrs = malloc(max_level * sizeof(skip_node_t *));
    for(i = 0; i < max_level; i++) {
	head_ptrs[i] = NULL;
    }
    
    t->n = 0;

    /* We prevent repeatedly allocating an updates array during each insertion,
     * by using an array which was allocated when the list was created.
     *
     * During insertion or deletion, entry update[i] is a pointer to the
     * forward[i] pointer is to be updated.
     */
    t->update = malloc(max_level * sizeof(skip_node_t **));

    return t;
}



/* skip_list_free() - Frees space used by the skip list pointed to by t. */
void skip_list_free(skip_list_t *t)
{
    skip_node_t *remove_node, *next;

    next = t->head_ptrs[0];
    while(next) {
	remove_node = next;
	next = remove_node->forward[0];
	free(remove_node->forward);
	free(remove_node);
    }

    free(t->head_ptrs);
    free(t->update);
    free(t);
}



/* skip_list_insert() - Inserts an item into the skip list pointed to by t,
 * according the the value its key.  The key of an item in the skip list must
 * be unique among items in the list.  If an item with the same key already
 * exists in the list, a pointer to that item is returned.  Otherwise, NULL is
 * returned, indicating insertion was successful.
 */
void *skip_list_insert(skip_list_t *t, void *item)
{
    skip_node_t *new_node, **forward, ***update;
    int (* compar)(const void *, const void *);
    int cmp_result;
    int i;
    int max_level, l;
    
    compar = t->compar;
    update = t->update;
    max_level = t->max_level;

    /* Locate insertion position. */
    forward = t->head_ptrs;
    i = max_level - 1;
    for(;;) {

	/* Ignore NULL pointers at the top of the forward pointer array. */
	while(forward[i] == NULL) {
	    update[i] = &forward[i];
	    i--;
            if(i < 0) goto end_find_loop;
	}

	/* Don't traverse toward nodes which are not smaller than the
	 * item being searched for.
	 */
        while((cmp_result = compar(forward[i]->item, item)) >= 0) {
	    update[i] = &forward[i];
	    i--;
	    if(i < 0) goto end_find_loop;
	}

	forward = forward[i]->forward;
    }
  end_find_loop:

    /* Check that the item being inserted does not have the same key as an item
     * already in the list.
     */
    if(forward[0] && cmp_result == 0) return forward[0]->item;

    /* Allocate a new node of a random size. */
    new_node = malloc(sizeof(skip_node_t));
    l = new_node->size = skip_list_rand_level(t->p, max_level);
    forward = new_node->forward = malloc(l * sizeof(skip_node_t *));
    new_node->item = item;

    /* Update pointers in the list. */
    for(i = 0; i < l; i++) {
	forward[i] = *update[i];
	*update[i] = new_node;
    }

    t->n++;
    
    return NULL;  /* Insertion successful. */
}



/* skip_list_find() - Find an item in the skip list with the same key as the
 * item pointed to by `key_item'.  Returns a pointer to the item found, or NULL
 * if no item was found.
 */
void *skip_list_find(skip_list_t *t, void *key_item)
{
    skip_node_t **forward;
    int (* compar)(const void *, const void *);
    int cmp_result;
    int i;
    int max_level;

    
    compar = t->compar;
    max_level = t->max_level;

    forward = t->head_ptrs;
    i = max_level - 1;
    for(;;) {

	/* Ignore NULL pointers at the top of the forward pointer array. */
	while(forward[i] == NULL) {
	    i--;
            if(i < 0) goto end_find_loop;
	}

	/* Don't traverse toward nodes which are not smaller than the
	 * item being searched for.
	 */
        while((cmp_result = compar(forward[i]->item, key_item)) >= 0) {
	    i--;
	    if(i < 0) goto end_find_loop;
	}

	forward = forward[i]->forward;
    }
  end_find_loop:
    
    /* Check if a matching item was found. */
    if(forward[0] && cmp_result == 0) return forward[0]->item;

    /* If this point is reached, a matching item was not found.
     */
    return NULL;
}



/* skip_list_find_min() - Returns a pointer to the minimum item in the skip
 * list pointed to by t.  If there are no items in the list a NULL pointer is
 * returned.
 */
void *skip_list_find_min(skip_list_t *t)
{
    return t->head_ptrs[0];
}

    

/* skip_list_delete() - Delete the first item found in the skip list with
 * the same key as the item pointed to by `key_item'.  Returns a pointer to the
 * deleted item, and NULL if no item was found.
 */
void *skip_list_delete(skip_list_t *t, void *item)
{
    skip_node_t *remove_node, **forward, ***update;
    int (* compar)(const void *, const void *);
    int cmp_result;
    int i;
    int max_level, l;
    void *return_item;

    
    compar = t->compar;
    update = t->update;
    max_level = t->max_level;

    /* Locate deletion position. */
    forward = t->head_ptrs;
    i = max_level - 1;
    for(;;) {

	/* Ignore NULL pointers at the top of the forward pointer array. */
	while(forward[i] == NULL) {
	    update[i] = &forward[i];
	    i--;
            if(i < 0) goto end_find_loop;
	}

	/* Don't traverse toward nodes which are not smaller than the
	 * item being searched for.
	 */
        while((cmp_result = compar(forward[i]->item, item)) >= 0) {
	    update[i] = &forward[i];
	    i--;
	    if(i < 0) goto end_find_loop;
	}

	forward = forward[i]->forward;
    }
  end_find_loop:

    remove_node = forward[0];
    
    /* A matching item may not have been found. */
    if(remove_node == NULL || cmp_result != 0) return NULL;
    /* else: */

    /* Item was found.  Update pointers. */
    l = remove_node->size;
    forward = remove_node->forward;
    for(i = 0; i < l; i++) {
        *update[i] = forward[i];
    }

    /* Free space and return the deleted item. */
    return_item = remove_node->item;
    free(forward);
    free(remove_node);

    t->n--;
    
    return return_item;
}



/* skip_list_delete_min() - Deletes the item with the smallest key from the
 * skip list pointed to by t.  Returns a pointer to the deleted item.
 * Returns a NULL pointer if there are no items in the list.
 */
void *skip_list_delete_min(skip_list_t *t)
{
    skip_node_t *remove_node, **forward, **head_ptrs;
    int i;
    int l;
    void *return_item;

    
    remove_node = t->head_ptrs[0];
    
    /* There may be no items in the list. */
    if(!remove_node) return NULL;
    /* else: */

    /* Item was found.  Update pointers. */
    l = remove_node->size;
    head_ptrs = t->head_ptrs;
    forward = remove_node->forward;
    for(i = 0; i < l; i++) {
        head_ptrs[i] = forward[i];
    }

    /* Free space and return the deleted item. */
    return_item = remove_node->item;
    free(forward);
    free(remove_node);

    t->n--;
    
    return return_item;
}



/* skip_list_rand_level() - Returns a random level, based on the probability,
 * p, and the maximum level allowed, max_level.
 */
int skip_list_rand_level(double p, int max_level)
{
    int i, rand_mark;

    rand_mark = p * RAND_MAX;

    for(i = 1; i < max_level; i++) {
        if(rand() > rand_mark) break;
    }

    return i;
}
--]]