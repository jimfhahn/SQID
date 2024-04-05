<template>
  <sqid-bars>
    <template v-slot:mainbar>
      <div v-if="banner" style="overflow: hidden;">
        <sqid-image :file="banner" width="850" />
      </div>
      <h1><span>{{ label }}</span></h1>
      <div id="aliases">
        <ul class="list-inline">
          <li class="list-inline-item" v-for="alias in aliases" :key="alias.value">{{ alias }}</li>
        </ul>
      </div>
      <div id="description">{{ description }}</div>
      <sqid-collapsible-card :header="'Works by'" :id="'yourId'" narrow>
      <b-card-body>
        <ul>
          <li v-for="(work, index) in works" :key="index">
            <!-- Replace 'work.title' with the actual property names in your data -->
            {{ work.title }}
          </li>
        </ul>
      </b-card-body>
    </sqid-collapsible-card>
    </template>
    <template v-slot:sidebar>
      <sqid-image :file="images[0]" width="260" v-if="images && images[0]" />
      <sqid-collapsible-card :header="$t('entity.links')" :id="links" narrow>
        <b-card-body>
          <table class="table table-striped table-sm narrow">
            <tbody>
              <tr v-for="(link, lidx) in links" :key="lidx">
                <th><a :href="link.url" target="_blank">{{ link.label }}</a></th>
              </tr>
            </tbody>
          </table>
        </b-card-body>
      </sqid-collapsible-card>
    </template>
  </sqid-bars>
</template>

<script lang="ts">
import { Component, Prop, Watch, Vue } from 'vue-property-decorator'
import { Getter, Action, Mutation, namespace } from 'vuex-class'
import Progress from '@/progress'
import { ClaimsMap, EntityId } from '@/store/entity/claims/types'
import ClaimTable from './ClaimTable.vue'
import SqidQualifierIcon from './SqidQualifierIcon.vue'
import { Claim, EntityKind, QualifiedEntityValue, WBDatatype } from '@/api/types'
import { relatedEntityIds, parseEntityId, idsFromQualifiedEntity, isPropertyId } from '@/api/wikidata'
import { groupClaims, RelatednessMapping, getClassHierarchyChunk, RELATED_PROPERTIES_THRESHOLD } from '@/api/sqid'
import { i18n } from '@/i18n'
import { fetchWorks } from '@/api/apiService';


@Component({
  components: {
    'claim-table': ClaimTable,
    'sqid-qualifier-icon': SqidQualifierIcon,
  }})
export default class Entity extends Vue {
  @Prop({ required: true }) private entityId!: string
  @Action private getEntityData: any
  @Action private getPropertyDatatypes: any
  @Action private getReverseClaims: any
  @Action private requestLabels: any
  @Action private getExampleItems!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleValues!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleInstances!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleSubclasses!: (entityId: EntityId) => Promise<EntityId[]>
  @Getter private getImages: any
  @Getter private getBanner: any
  @Getter private getHomepage: any
  @Getter private getWikidataUrl: any
  @Getter private getWikipediaUrl: any
  @Getter private getReasonatorUrl: any
  @Getter private getValuesForProperty!: (entityId: EntityId, propertyId: EntityId) => Array<{}>
  @Getter private getPropertyDatatype!: (entityId: EntityId) => WBDatatype | undefined
  private linkUrls: Array<{ url: string, label: any }> = []
  private label = this.entityId
  private aliases: string[] = []
  private description: string | null = null
  private claims: ClaimsMap | null = null
  private reverseClaims: ClaimsMap | null = null
  private images: string[] | null = null
  private banner: string | null = null
  private kind: EntityKind | null = null
  private propertyDatatype: WBDatatype | null = null
  private superProperties: QualifiedEntityValue[] = []
  private superClasses: QualifiedEntityValue[] = []
  private superClassesUsage: Map<EntityId, number> = new Map<EntityId, number>()
  private instanceClasses: QualifiedEntityValue[] = []
  private subclassesInstances: { [key: string]: number } = {}
  private subclassesSubclasses: { [key: string]: number } = {}
  private typicalProperties: EntityId[] = []
  private exampleItems: EntityId[] = []
  private exampleValues: EntityId[] = []
  private exampleInstances: EntityId[] = []
  private exampleSubclasses: EntityId[] = []



  private updateEntityData() {
    Progress.start()
    this.images = null
    this.banner = null
    const { kind } = parseEntityId(this.entityId)
    this.kind = kind
    this.propertyDatatype = null
    this.superProperties = []
    this.superClasses = []
    this.superClassesUsage = new Map<EntityId, number>()
    this.instanceClasses = []
    this.typicalProperties = []
    this.exampleItems = []
    this.exampleValues = []
    this.exampleInstances = []
    this.exampleSubclasses = []
    this.subclassesInstances = {}
    this.subclassesSubclasses = {}
    this.claims = null
    this.reverseClaims = null
    document.title = `${this.label} – SQID`


    const forwardClaims = this.getEntityData(this.entityId)
      .then((data: {
        label: string
        aliases: string[]
        description: string
        claims: ClaimsMap}) => {
          if (data.label) {
            this.label = data.label
            document.title = `${this.label} (${this.entityId}) – SQID`
          } else {
            this.label = this.entityId
            document.title = `${this.label} – SQID`
          }
          this.aliases = data.aliases
          this.description = data.description
          this.claims = data.claims

          const related = relatedEntityIds(this.claims)
          this.requestLabels({entityIds: related})

          const properties = []
          for (const entityId of related) {
            if (isPropertyId(entityId as EntityId)) {
              properties.push(entityId)
            }
          }

          this.getPropertyDatatypes(properties)

          this.images = this.getImages(this.entityId)
          this.banner = this.getBanner(this.entityId)

          if (kind === 'property') {
            this.propertyDatatype = this.getPropertyDatatype(this.entityId) || null

            const values = (this.getValuesForProperty(this.entityId, 'P1647') as QualifiedEntityValue[]) || []
            this.superProperties = values
          }

          const superClasses = (this.getValuesForProperty(this.entityId, 'P279') as QualifiedEntityValue[]) || []
          this.superClasses = superClasses

          const instanceClasses = (this.getValuesForProperty(this.entityId, 'P31') as QualifiedEntityValue[]) || []
          this.instanceClasses = instanceClasses

          const entityIds = ['P1647', 'P279', 'P31'].concat(
            ...this.superProperties.map(idsFromQualifiedEntity),
            ...this.superClasses.map(idsFromQualifiedEntity),
            ...this.instanceClasses.map(idsFromQualifiedEntity))
          this.requestLabels({ entityIds })
        })
    const reverseClaims = this.getReverseClaims(this.entityId)
      .then((claims: ClaimsMap) => {
        this.reverseClaims = claims

        const related = relatedEntityIds(claims)
        this.requestLabels({entityIds: related})

        const properties = []

        for (const entityId of related) {
          if (isPropertyId(entityId as EntityId)) {
            properties.push(entityId)
          }
        }

        this.getPropertyDatatypes(properties)
      })

 
      .then(() => {
        const properties = []

        for (const property of this.claims!.keys()) {
          properties.push(property)
        }

        for (const property of this.reverseClaims!.keys()) {
          properties.push(property)
        }
      }).then(() => Progress.done())
  }


  private async created() {
  this.onEntityIdChanged();
  this.updateLinks();
  this.works = await fetchWorks(this.svdeAgentId);
}

  @Watch('entityId')
  private onEntityIdChanged() {
    this.updateEntityData()
  }

  private get wikidata() {
    return this.getWikidataUrl(this.entityId)
  }

  @Watch('claims')
  private updateLinks() {
    const urls: Array<{ url: string, label: any }> =
      [{ url: this.wikidata,
         label: this.$t('entity.wikidataLink'),
       }]

    const homepage = this.getHomepage(this.entityId)
    if (homepage !== null) {
      urls.push({ url: homepage,
                  label: this.$t('entity.homepageLink'),
                })
    }

    const wikipedia = this.getWikipediaUrl(this.entityId)

    if (wikipedia !== null) {
      urls.push({ url: wikipedia,
                  label: this.$t('entity.wikipediaLink'),
                })
    }

    urls.push({ url: this.getReasonatorUrl(this.entityId),
                label: this.$t('entity.reasonatorLink'),
              })

    this.linkUrls = urls
  }

  private get links() {
    return this.linkUrls
  }

  private compareByCount(left: { count: number }, right: { count: number }) {
    const lhs = left.count
    const rhs = right.count

    if (lhs < rhs) {
      return 1
    }

    if (lhs > rhs) {
      return -1
    }

    return 0
  }

  private get sortedSubclassesInstances() {
    const result = []

    for (const [subclassId, count] of Object.entries(this.subclassesInstances)) {
      result.push({ id: subclassId,
                    count,
                  })
    }

    return result.sort(this.compareByCount)
  }

  private get sortedSubclassesSubclasses() {
    const result = []

    for (const [subclassId, count] of Object.entries(this.subclassesSubclasses)) {
      result.push({ id: subclassId,
                    count,
                  })
    }

    return result.sort(this.compareByCount)
  }
}
</script>

<style lang="less" scoped>
#aliases {
  margin-top: -10px;
  margin-bottom: 0px;
  color: #999999;
}

#aliases ul {
  margin-top: -10px;
  margin-bottom: 0px;
}

#aliases ul li {
  margin-top: -10px;
  padding-right: 0px;
}

#aliases ul li::after {
  content: " |";
}

#aliases ul li:last-child::after {
  content: "";
}

#description {
  font-size: 1.3em;
}

table {
  table-layout: fixed;
  margin-bottom: 0px !important;

  &:not(.narrow) th {
    width: 25%;
  }
}

.card-body {
  padding: 0 0;
}

.four-lines {
  overflow: auto;
  max-height: 6em;
}

.comma-separated {
  display: inline;
  list-style: none;
  padding: 0;

  li {
    display: inline;
  }

  li::after {
    content: ", ";
  }

  li:last-child::after {
    content: "";
  }

.badge {
  margin-left: .25em;
  margin-right: .05em;
}
}
</style>