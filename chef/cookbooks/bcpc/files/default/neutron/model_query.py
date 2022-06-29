#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


"""
NOTE: This module is a temporary shim until networking projects move to
      versioned objects at which point this module shouldn't be needed.
"""
from oslo_db.sqlalchemy import utils as sa_utils
from sqlalchemy import sql, or_, and_

from neutron_lib._i18n import _
from neutron_lib.api import attributes
from neutron_lib.db import utils as db_utils
from neutron_lib import exceptions as n_exc
from neutron_lib.objects import utils as obj_utils
from neutron_lib.utils import helpers


# Classes implementing extensions will register hooks into this dictionary
# for "augmenting" the "core way" of building a query for retrieving objects
# from a model class. Hooks are registered by invoking register_hook().
_model_query_hooks = {
    # model1 : {
    #              hook1: {
    #                         'query': query_hook,
    #                         'filter': filter_hook,
    #                         'result_filters': result_filters
    #              },
    #              hook2: {
    #                         'query': query_hook,
    #                         'filter': filter_hook,
    #                         'result_filters': result_filters
    #              },
    #              ...
    #          },
    # model2 : {
    #              hook1: {
    #                         'query': query_hook,
    #                         'filter': filter_hook,
    #                         'result_filters': result_filters
    #              },
    #              hook2: {
    #                         'query': query_hook,
    #                         'filter': filter_hook,
    #                         'result_filters': result_filters
    #              },
    #              ...
    #          },
    # ...
}


def register_hook(model, name, query_hook, filter_hook,
                  result_filters=None, rbac_filter_hook=None):
    """Register a hook to be invoked when a query is executed.

    Adds the hook components to the _model_query_hooks dict. Models are the
    keys of this dict, whereas the value is another dict mapping hook names
    to callables performing the hook.

    :param model: The DB Model that the hook applies to.
    :param name: A name for the hook.
    :param query_hook: The method to be called to augment the query.
    :param filter_hook: A method to be called to augment the query filter.
    :param result_filters: A Method to be called to filter the query result.
    :returns: None.
    """
    if callable(query_hook):
        query_hook = helpers.make_weak_ref(query_hook)
    if callable(filter_hook):
        filter_hook = helpers.make_weak_ref(filter_hook)
    if callable(result_filters):
        result_filters = helpers.make_weak_ref(result_filters)
    if callable(rbac_filter_hook):
        rbac_filter_hook = helpers.make_weak_ref(rbac_filter_hook)
    _model_query_hooks.setdefault(model, {})[name] = {
        'query': query_hook,
        'filter': filter_hook,
        'result_filters': result_filters,
        'rbac_filter': rbac_filter_hook,
    }


def get_hooks(model):
    """Retrieve the model query hooks for a model.

    :param model: The DB Model to look up for query hooks.
    :returns: list of hooks
    """
    return _model_query_hooks.get(model, {}).values()


def _prep_query_with_hooks(context, model, field):
    """Prepares a SQLalchemy query for use with query_with_hooks.

    :param context: The context to use for the DB session.
    :param model: The model to query.
    :param field: The column.
    :returns: The query with hooks applied to it.
    """
    if field:
        if hasattr(model, field):
            field = getattr(model, field)
        else:
            msg = _("'%s' is not supported as field") % field
            raise n_exc.InvalidInput(error_message=msg)
        return context.session.query(field)
    return context.session.query(model)


def query_with_hooks(context, model, field=None, hoisted_filters=None):
    """Query with hooks using the said context and model.

    :param context: The context to use for the DB session.
    :param model: The model to query.
    :param field: The column.
    :returns: The query with hooks applied to it.
    """
    query = _prep_query_with_hooks(context, model, field)
    query_to_union = None
    # define basic filter condition for model query
    query_filter = None
    model_query_filter, rbac_query_filter = None, None
    if db_utils.model_query_scope_is_project(context, model):
        if hasattr(model, 'rbac_entries'):
            query = query.join(model.rbac_entries)
            query_to_union = _prep_query_with_hooks(context, model, field)
            rbac_model = model.rbac_entries.property.mapper.class_
            model_query_filter = (model.tenant_id == context.tenant_id)
            rbac_query_filter = (
                ((rbac_model.action == 'access_as_shared') &
                 ((rbac_model.target_tenant == context.tenant_id) |
                  (rbac_model.target_tenant == '*'))))
        elif hasattr(model, 'shared'):
            query_filter = ((model.tenant_id == context.tenant_id) |
                            (model.shared == sql.true()))
        else:
            query_filter = (model.tenant_id == context.tenant_id)
    # Execute query hooks registered from mixins and plugins
    for hook in get_hooks(model):
        query_hook = helpers.resolve_ref(hook.get('query'))
        if query_hook:
            query = query_hook(context, model, query)

        filter_hook = helpers.resolve_ref(hook.get('filter'))
        if filter_hook:
            query_filter = filter_hook(context, model, query_filter)

        filter_hook = helpers.resolve_ref(hook.get('rbac_filter'))
        if filter_hook:
            rbac_query_filter = filter_hook(context, model, rbac_query_filter)

    # NOTE(tstachecki): this code used to live in apply_filters(...), but
    # we have to evaluate it here before we union off the RBAC columns.
    if hoisted_filters:
        for key, value in hoisted_filters.items():
            if key != 'shared' or not hasattr(model, 'rbac_entries'):
                continue
            # translate a filter on shared into a query against the
            # object's rbac entries
            rbac = model.rbac_entries.property.mapper.class_
            matches = [rbac.target_tenant == '*']
            if context:
                matches.append(rbac.target_tenant == context.tenant_id)
            # any 'access_as_shared' records that match the
            # wildcard or requesting tenant
            is_shared = and_(rbac.action == 'access_as_shared',
                             or_(*matches))
            if not value[0]:
                # NOTE(kevinbenton): we need to find objects that don't
                # have an entry that matches the criteria above so
                # we use a subquery to exclude them.
                # We can't just filter the inverse of the query above
                # because that will still give us a network shared to
                # our tenant (or wildcard) if it's shared to another
                # tenant.
                # This is the column joining the table to rbac via
                # the object_id. We can't just use model.id because
                # subnets join on network.id so we have to inspect the
                # relationship.
                join_cols = model.rbac_entries.property.local_columns
                oid_col = list(join_cols)[0]
                is_shared = ~oid_col.in_(
                    query.session.query(rbac.object_id).filter(is_shared)
                )
            elif (not context or
                  not db_utils.model_query_scope_is_project(
                      context, model)):
                # we only want to join if we aren't using the subquery
                # and if we aren't already joined because this is a
                # scoped query
                query = query.join(model.rbac_entries).filter(is_shared)
            # NOTE(tstachecki): as we are doing comparisons to RBAC-
            # based fields, we now need to ensure that networks without
            # RBACs are filtered out to maintain parity with old code.
            else:
                query_to_union = None
            if rbac_query_filter is not None:
                rbac_query_filter = and_(rbac_query_filter, is_shared)
            else:
                rbac_query_filter = is_shared

    # NOTE(tstachecki): To avoid upsetting the MySQL optimizer, instead of
    # doing an OUTER JOIN above, do an INNER JOIN there and UNION it with
    # the outside here.
    if rbac_query_filter is not None:
        query = query.filter(rbac_query_filter)

    if query_to_union is not None:
        if model_query_filter is not None:
            query_to_union = query_to_union.filter(model_query_filter)

        query = query.union(query_to_union)

    # NOTE(salvatore-orlando): 'if query_filter' will try to evaluate the
    # condition, raising an exception
    if query_filter is not None:
        query = query.filter(query_filter)

    return query


def get_by_id(context, model, object_id):
    """Query the said model with the given context for a specific object.

    :param context: The context to use in the query.
    :param model: The model to query.
    :param object_id: The ID of the object to query for.
    :returns: The object with the give object_id for the said model.
    """
    query = query_with_hooks(context=context, model=model)
    return query.filter(model.id == object_id).one()


def apply_filters(query, model, filters, context=None):
    """Apply filters to a query.

    :param query: The query to apply filters to.
    :param model: The model for the query.
    :param filters: The filters to apply.
    :param context: The context to use for the DB session.
    :returns: The query with filters applied to it.
    """
    if filters:
        for key, value in filters.items():
            column = getattr(model, key, None)
            # NOTE(kevinbenton): if column is a hybrid property that
            # references another expression, attempting to convert to
            # a boolean will fail so we must compare to None.
            # See "An Important Expression Language Gotcha" in:
            # docs.sqlalchemy.org/en/rel_0_9/changelog/migration_06.html
            if column is not None:
                if not value:
                    query = query.filter(sql.false())
                    return query
                if not hasattr(column, 'in_'):
                    # NOTE(ralonsoh): since SQLAlchemy==1.3.0, a column is an
                    # AssociationProxyInstance and inherits in_() method from
                    # ColumnOperators.
                    # association proxies don't support in_ so we have to
                    # do multiple equals matches
                    query = query.filter(
                        or_(*[column == v for v in value]))
                elif isinstance(value, obj_utils.FilterObj):
                    query = query.filter(value.filter(column))
                elif None in value:
                    # in_() operator does not support NULL element so we have
                    # to do multiple equals matches
                    query = query.filter(
                        or_(*[column == v for v in value]))
                else:
                    # NOTE(frickler): in_() isn't implemented for relations
                    # yet, let this pass so it can be handled by the
                    # result_filter hook
                    try:
                        query = query.filter(column.in_(value))
                    except NotImplementedError:
                        pass
        for hook in get_hooks(model):
            result_filter = helpers.resolve_ref(
                hook.get('result_filters', None))
            if result_filter:
                query = result_filter(query, filters)
    return query


def get_collection_query(context, model, filters=None, sorts=None, limit=None,
                         marker_obj=None, page_reverse=False):
    """Get a collection query.

    :param context: The context to use for the DB session.
    :param model: The model to use.
    :param filters: The filters to apply in the query.
    :param sorts: The sort keys to use.
    :param limit: The limit associated with the query.
    :param marker_obj: The marker object if applicable.
    :param page_reverse: If reverse paging should be used.
    :returns: A paginated query for the said model.
    """
    collection = query_with_hooks(context, model, hoisted_filters=filters)
    collection = apply_filters(collection, model, filters, context)
    if sorts:
        sort_keys = db_utils.get_and_validate_sort_keys(sorts, model)
        sort_dirs = db_utils.get_sort_dirs(sorts, page_reverse)
        # we always want deterministic results for sorted queries
        # so add unique keys to limit queries when present.
        # (http://docs.sqlalchemy.org/en/latest/orm/
        #  loading_relationships.html#subqueryload-ordering)
        # (http://docs.sqlalchemy.org/en/latest/faq/
        #  ormconfiguration.html#faq-subqueryload-limit-sort)
        for k in _unique_keys(model):
            if k not in sort_keys:
                sort_keys.append(k)
                sort_dirs.append('asc')
        collection = sa_utils.paginate_query(collection, model, limit,
                                             marker=marker_obj,
                                             sort_keys=sort_keys,
                                             sort_dirs=sort_dirs)
    return collection


def _unique_keys(model):
    # just grab first set of unique keys and use them.
    # if model has no unqiue sets, 'paginate_query' will
    # warn if sorting is unstable
    uk_sets = sa_utils.get_unique_keys(model)
    return uk_sets[0] if uk_sets else []


def get_collection(context, model, dict_func,
                   filters=None, fields=None,
                   sorts=None, limit=None, marker_obj=None,
                   page_reverse=False):
    """Get a collection for a said model.

    :param context: The context to use for the DB session.
    :param model: The model for the collection.
    :param dict_func: The function used to build the collection dict.
    :param filters: The filters to apply.
    :param fields: The fields to collect.
    :param sorts: The sort keys to use.
    :param limit: The limit for the query if applicable.
    :param marker_obj: The marker object if applicable.
    :param page_reverse: If reverse paging should be used.
    :returns: A list of dicts where each dict is an object in the collection.
    """
    query = get_collection_query(context, model,
                                 filters=filters, sorts=sorts,
                                 limit=limit, marker_obj=marker_obj,
                                 page_reverse=page_reverse)
    items = [
        attributes.populate_project_info(
            dict_func(c, fields) if dict_func else c)
        for c in query
    ]
    if limit and page_reverse:
        items.reverse()
    return items


def get_values(context, model, field, filters=None):
    query = query_with_hooks(context, model, field=field, hoisted_filters=filters)
    query = apply_filters(query, model, filters, context)
    return [c[0] for c in query]


def get_collection_count(context, model, filters=None):
    """Get the count for a specific collection.

    :param context: The context to use for the DB session.
    :param model: The model for the query.
    :param filters: The filters to apply.
    :returns: The number of objects for said model with filters applied.
    """
    return get_collection_query(context, model, filters).count()
